package chatappserver

import "core:fmt"
import "core:net"
import "core:mem"
import "core:os"
import "core:strings"
import "core:thread"
import "core:time"
import "core:bytes"

ADDR :: "127.0.0.1"

ClientTask :: struct #align(4) {
    socket: ^net.TCP_Socket,
    clientEndpoint: net.Endpoint,
    clientID: i64
}

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

    addr, ok := net.parse_ip4_address(ADDR)
    endpoint : net.Endpoint
    endpoint.address = addr
    endpoint.port = 8888
    fmt.printfln("Starting server %s on port %v", ADDR, endpoint.port)
    socket, netErr := net.listen_tcp(endpoint)
    if netErr != nil {
        fmt.println(netErr)
        return
    }

    N :: 6
    pool : thread.Pool
    thread.pool_init(&pool, context.allocator, N)
    defer thread.pool_destroy(&pool)
    thread.pool_start(&pool)

    clientID : i64 = 0

    for {
        clientSock, clientEnd, acceptErr := net.accept_tcp(socket)
        if acceptErr != nil do fmt.panicf("%s", acceptErr)
        task := ClientTask{clientEndpoint=clientEnd, socket=&clientSock, clientID=clientID}
        clientID += 1
        thread.pool_add_task(&pool, context.allocator, handleClientTask, &task)
    }
}

handleClientTask :: proc(task: thread.Task) {
    clientTask := transmute(^ClientTask)task.data
    client := clientTask.clientID
    socket := clientTask.socket^
    duration : time.Duration = 5
    net.set_option(socket, net.Socket_Option.Receive_Timeout, duration)
    for {
        data : [1024]byte
        n, recvErr := net.recv_tcp(socket, data[:])
        if recvErr != nil {
            fmt.println("Network Error:", recvErr)
            net.close(socket)
            return
        }
        recvData := strings.trim(string(data[:n]), "\000")
        if len(recvData) <= 0 do continue
        recvData = recvData[:len(recvData)-2]
        if recvData[:4] == "exit" {
            fmt.printfln("Connection %v closed", client)
            net.close(socket)
            return
        }
        fmt.printfln("Client %v said: %s", client, recvData)
        _, sendErr := net.send_tcp(socket, data[:])
        if sendErr != nil {
            fmt.println("sendErr:", sendErr)
        }
    }
}
