package chatappclient

import "core:fmt"
import "core:net"
import "core:os"
import "core:time"
import "core:strings"

main :: proc() {
    buff : [1024]byte
    socket : net.TCP_Socket
    addr := net.parse_address("127.0.0.1")

    serverEndpoint : net.Endpoint
    serverEndpoint.address = addr
    serverEndpoint.port = 8888
    connErr : net.Network_Error
    socket, connErr = net.dial_tcp_from_endpoint(serverEndpoint)
    if connErr != nil do fmt.panicf("Connection error")

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
        duration : time.Duration = 5
        net.set_option(socket, net.Socket_Option.Receive_Timeout, duration)
        _, recvErr := net.recv_tcp(socket, buff[:])
        if recvErr != nil do fmt.panicf("%s", recvErr)
        recvString := string(buff[:])
        recvString = strings.trim(recvString, "\000")
        recvString = recvString[:len(recvString)-2]
        fmt.println("You sent:", recvString)
    }
}
