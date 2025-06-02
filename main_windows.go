//go:build windows
// +build windows

package main

import (
	"os"
	"syscall"
)

func init() {
	// Hide console window
	getConsoleWindow := syscall.NewLazyDLL("kernel32.dll").NewProc("GetConsoleWindow")
	showWindow := syscall.NewLazyDLL("user32.dll").NewProc("ShowWindow")

	hwnd, _, _ := getConsoleWindow.Call()
	if hwnd != 0 {
		showWindow.Call(hwnd, 0) // SW_HIDE = 0
	}

	// Redirect stdout and stderr to log files
	logFile, err := os.OpenFile("logs/service.log", os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	if err == nil {
		os.Stdout = logFile
		os.Stderr = logFile
	}
}
