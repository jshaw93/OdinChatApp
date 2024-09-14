package chatappclient

import "core:fmt"
import "core:net"
import "core:os"
import "core:time"
import "core:strings"
import "core:mem"

main :: proc() {
    when ODIN_DEBUG {
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer {
            if len(track.allocation_map) > 0 {
                fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
                for _, entry in track.allocation_map {
                    fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                }
            }
            if len(track.bad_free_array) > 0 {
                fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
                for entry in track.bad_free_array {
                    fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track)
        }
    }

    buff : [1024]byte // Message buffer, take in stdin and send to server/recv from server
    
    // Create TCP connection to server
    socket : net.TCP_Socket
    addr := net.parse_address("127.0.0.1")
    serverEndpoint : net.Endpoint
    serverEndpoint.address = addr
    serverEndpoint.port = 8888
    connErr : net.Network_Error
    socket, connErr = net.dial_tcp_from_endpoint(serverEndpoint)
    if connErr != nil do fmt.panicf("Connection error: %s", connErr)

    for {
        // Send to server
        n, readErr := os.read(os.stdin, buff[:])
        if readErr != nil do fmt.panicf("Read error %s", readErr)
        conn, err := net.send_tcp(socket, buff[:])
        if string(buff[:4]) == "exit" {
            net.close(socket)
            break
        }

        // Handle Reply
        _, recvErr := net.recv_tcp(socket, buff[:])
        if recvErr != nil do fmt.panicf("%s", recvErr)
        recvString := string(buff[:])
        recvString = strings.trim(recvString, "\000") // Cya later null bytes
        recvString = recvString[:len(recvString)-2] // Trim non-printable characters
        fmt.println("From server:", recvString)
    }
}
