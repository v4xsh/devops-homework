package com.vansh.hello;

import com.sun.net.httpserver.HttpServer;

import java.io.OutputStream;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;

public class App {
    public static void main(String[] args) throws Exception {
        HttpServer server = HttpServer.create(new InetSocketAddress(8080), 0);
        String host = InetAddress.getLocalHost().getHostName();
        server.createContext("/", ex -> {
            byte[] body = ("<h1>Hello World from Java - Session 7 - Vansh Dobhal (10099)</h1>"
                    + "<p>container: " + host + "</p>\n").getBytes(StandardCharsets.UTF_8);
            ex.getResponseHeaders().set("Content-Type", "text/html; charset=utf-8");
            ex.sendResponseHeaders(200, body.length);
            try (OutputStream os = ex.getResponseBody()) {
                os.write(body);
            }
        });
        server.start();
        System.out.println("java app listening on 8080");
    }
}
