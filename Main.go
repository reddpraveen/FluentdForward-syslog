package main

import (
	"bufio"
	"fmt"
	"log"
	"net"
	"strings"
)

func main() {
	// Define the address to listen for syslog messages (on port 5140 for syslog over TCP)
	address := "0.0.0.0:5140"
	listener, err := net.Listen("tcp", address)
	if err != nil {
		log.Fatalf("Error setting up TCP listener: %v", err)
	}
	defer listener.Close()

	log.Printf("Listening for syslog messages on %s...\n", address)

	// Listen for incoming connections
	for {
		conn, err := listener.Accept()
		if err != nil {
			log.Printf("Error accepting connection: %v", err)
			continue
		}

		// Handle incoming syslog messages
		go handleSyslogConnection(conn)
	}
}

func handleSyslogConnection(conn net.Conn) {
	defer conn.Close()

	reader := bufio.NewReader(conn)
	for {
		message, err := reader.ReadString('\n')
		if err != nil {
			log.Printf("Error reading from connection: %v", err)
			return
		}

		// Print the syslog message received (for debugging purposes)
		fmt.Printf("Received syslog message: %s", strings.TrimSpace(message))

		// Convert the syslog message to FluentdForward format
		fluentdMessage := convertToFluentdForward(message)

		// Send the FluentdForward message to the remote host
		sendToFluentdForward(fluentdMessage)
	}
}

// Dummy function to convert syslog message to FluentdForward format
func convertToFluentdForward(syslogMessage string) string {
	// You can modify this to match your desired conversion logic
	// For simplicity, just returning a basic JSON representation
	return fmt.Sprintf(`{"tag": "syslog", "message": "%s"}`, strings.TrimSpace(syslogMessage))
}

// Dummy function to send FluentdForward messages to remote server via TCP
func sendToFluentdForward(fluentdMessage string) {
	// Define the remote Fluentd Forward server (replace with your actual remote host)
	remoteAddress := "remote-fluentd-server.com:24224"

	conn, err := net.Dial("tcp", remoteAddress)
	if err != nil {
		log.Printf("Error connecting to Fluentd Forward server: %v", err)
		return
	}
	defer conn.Close()

	// Send the message
	_, err = conn.Write([]byte(fluentdMessage + "\n"))
	if err != nil {
		log.Printf("Error sending FluentdForward message: %v", err)
		return
	}

	log.Printf("Sent FluentdForward message: %s", fluentdMessage)
}
