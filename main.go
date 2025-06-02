package main

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"os"
	"os/user"
	"path/filepath"
	"strings"
	"time"

	"github.com/gocarina/gocsv"
	_ "modernc.org/sqlite"
)

// Record represents a CSV record
type Record struct {
	IP     string    `csv:"ip"`
	ID     string    `csv:"id"`
	Prompt string    `csv:"prompt"`
	Hash   string    `csv:"hash"`
	Time   time.Time `csv:"time"`
}

// PromptData represents the structure of the value column data
type PromptData struct {
	Text        string `json:"text"`
	CommandType int    `json:"commandType"`
}

const (
	outputDir     = "output"
	outputFile    = "out.csv"
	stateFile     = "state.vscdb"
	checkInterval = 5 * time.Minute
)

var (
	processedHashes = make(map[string]bool)
	localIP         string
	userID          string
)

func init() {
	// Get local IP
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		log.Fatal(err)
	}
	for _, addr := range addrs {
		if ipnet, ok := addr.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
			if ipnet.IP.To4() != nil {
				localIP = ipnet.IP.String()
				break
			}
		}
	}

	// Get user ID
	currentUser, err := user.Current()
	if err != nil {
		log.Fatal(err)
	}
	userID = currentUser.Username

	// Create output directory
	if err := os.MkdirAll(outputDir, 0755); err != nil {
		log.Fatal(err)
	}

	// Load existing records to avoid duplicates
	loadExistingRecords()
}

// calculateHash generates a SHA-256 hash of the prompt text
func calculateHash(text string) string {
	hash := sha256.Sum256([]byte(text))
	return hex.EncodeToString(hash[:])
}

func loadExistingRecords() {
	file := filepath.Join(outputDir, outputFile)
	if _, err := os.Stat(file); os.IsNotExist(err) {
		return
	}

	f, err := os.OpenFile(file, os.O_RDONLY, 0644)
	if err != nil {
		log.Printf("Error opening existing CSV file: %v", err)
		return
	}
	defer f.Close()

	var records []Record
	if err := gocsv.UnmarshalFile(f, &records); err != nil {
		log.Printf("Error reading existing CSV records: %v", err)
		return
	}

	for _, record := range records {
		processedHashes[record.Hash] = true
	}
}

func main() {
	// Get base directory path
	baseDir := filepath.Join(os.Getenv("APPDATA"), "Cursor", "User", "workspaceStorage")

	log.Printf("Starting monitor. Base directory: %s", baseDir)
	log.Printf("Output file: %s", filepath.Join(outputDir, outputFile))

	// Initial scan
	processExistingDirectories(baseDir)

	// Periodic scan
	ticker := time.NewTicker(checkInterval)
	defer ticker.Stop()

	log.Printf("Monitoring started. Check interval: %v", checkInterval)

	for range ticker.C {
		processExistingDirectories(baseDir)
	}
}

func processExistingDirectories(baseDir string) {
	entries, err := os.ReadDir(baseDir)
	if err != nil {
		log.Printf("Error reading base directory: %v", err)
		return
	}

	for _, entry := range entries {
		if entry.IsDir() {
			dbPath := filepath.Join(baseDir, entry.Name(), stateFile)
			processPath(dbPath)
		}
	}
}

func processPath(path string) {
	if !strings.HasSuffix(path, stateFile) {
		return
	}

	if _, err := os.Stat(path); os.IsNotExist(err) {
		return
	}

	db, err := sql.Open("sqlite", path)
	if err != nil {
		log.Printf("Error opening database %s: %v", path, err)
		return
	}
	defer db.Close()

	// Check if ItemTable exists and has required columns
	var count int
	err = db.QueryRow(`
		SELECT COUNT(*) FROM sqlite_master 
		WHERE type='table' AND name='ItemTable'
	`).Scan(&count)
	if err != nil || count == 0 {
		return
	}

	// Query for prompts
	rows, err := db.Query(`
		SELECT value FROM ItemTable 
		WHERE key = 'aiService.prompts'
	`)
	if err != nil {
		log.Printf("Error querying database: %v", err)
		return
	}
	defer rows.Close()

	for rows.Next() {
		var value string
		if err := rows.Scan(&value); err != nil {
			log.Printf("Error scanning row: %v", err)
			continue
		}

		var promptDataList []PromptData
		if err := json.Unmarshal([]byte(value), &promptDataList); err != nil {
			log.Printf("Error unmarshaling JSON: %v", err)
			continue
		}

		for _, promptData := range promptDataList {
			if promptData.Text == "" {
				continue
			}

			hash := calculateHash(promptData.Text)
			if processedHashes[hash] {
				continue
			}

			record := Record{
				IP:     localIP,
				ID:     userID,
				Prompt: promptData.Text,
				Hash:   hash,
				Time:   time.Now().UTC(),
			}

			if err := writeRecord(record); err != nil {
				log.Printf("Error writing record: %v", err)
				continue
			}

			processedHashes[hash] = true
		}
	}
}

func writeRecord(record Record) error {
	file := filepath.Join(outputDir, outputFile)

	// Check if file exists
	var records []Record
	if _, err := os.Stat(file); err == nil {
		// Read existing records
		f, err := os.OpenFile(file, os.O_RDONLY, 0644)
		if err != nil {
			return fmt.Errorf("error opening existing CSV file: %v", err)
		}
		if err := gocsv.UnmarshalFile(f, &records); err != nil {
			f.Close()
			return fmt.Errorf("error reading existing CSV records: %v", err)
		}
		f.Close()
	}

	// Append new record
	records = append(records, record)

	// Write all records
	f, err := os.OpenFile(file, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0644)
	if err != nil {
		return fmt.Errorf("error creating CSV file: %v", err)
	}
	defer f.Close()

	return gocsv.MarshalFile(&records, f)
}
