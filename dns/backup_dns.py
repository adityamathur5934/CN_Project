#!/usr/bin/env python3
"""
Backup DNS Resolver for CN Project (Mac 4 - 10.7.16.36)
Pure Python 3 standard library.
Serves A records for app.team1.test and api.team1.test with configurable TTL.
"""

import socket
import struct
import sys
import argparse

DEFAULT_IP = "10.7.17.151"   # Mac 2 Edge IP
DEFAULT_TTL = 30             # 30 seconds visible TTL for Script 9 Objective B

DOMAINS = {
    "app.team1.test": DEFAULT_IP,
    "api.team1.test": DEFAULT_IP,
}

def parse_domain_name(data, offset):
    labels = []
    while True:
        length = data[offset]
        if length == 0:
            offset += 1
            break
        offset += 1
        labels.append(data[offset:offset+length].decode('utf-8', errors='ignore'))
        offset += length
    return ".".join(labels), offset

def build_dns_response(data, target_ip, ttl):
    # Transaction ID (2 bytes)
    tx_id = data[:2]
    # Flags: Standard query response, No error (0x8180)
    flags = b'\x81\x80'
    # QDCOUNT (1), ANCOUNT (1), NSCOUNT (0), ARCOUNT (0)
    counts = b'\x00\x01\x00\x01\x00\x00\x00\x00'

    # Read question section
    domain, q_end = parse_domain_name(data, 12)
    # Question type & class (4 bytes: type A = 1, class IN = 1)
    qtype_qclass = data[q_end:q_end+4]

    # Question section to echo back
    question = data[12:q_end+4]

    # Answer section:
    # Pointer to domain in question section (offset 12 -> 0xc00c)
    ans_name = b'\xc0\x0c'
    # Type A (1), Class IN (1)
    ans_type_class = b'\x00\x01\x00\x01'
    # TTL (4 bytes)
    ans_ttl = struct.pack(">I", ttl)
    # Data length (4 bytes for IPv4)
    ans_len = b'\x00\x04'
    # IPv4 address bytes
    ip_parts = [int(p) for p in target_ip.split(".")]
    ans_ip = bytes(ip_parts)

    answer = ans_name + ans_type_class + ans_ttl + ans_len + ans_ip
    return tx_id + flags + counts + question + answer, domain

def run_dns_server(host="0.0.0.0", port=53, target_ip=DEFAULT_IP, ttl=DEFAULT_TTL):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.bind((host, port))
    except PermissionError:
        print(f"[Backup DNS] Permission denied binding to port {port}. Please run with sudo: sudo python3 {sys.argv[0]}", file=sys.stderr)
        sys.exit(1)
    except OSError as e:
        print(f"[Backup DNS] Error binding to {host}:{port}: {e}", file=sys.stderr)
        sys.exit(1)

    print("=========================================================")
    print(f"  Backup DNS Server running on {host}:{port}")
    print(f"  Target Edge IP: {target_ip}")
    print(f"  Record TTL:     {ttl} seconds")
    print(f"  Domains:")
    for d in DOMAINS:
        print(f"    - {d} -> {target_ip} (TTL: {ttl}s)")
    print("=========================================================")

    try:
        while True:
            data, addr = sock.recvfrom(512)
            try:
                response, domain = build_dns_response(data, target_ip, ttl)
                sock.sendto(response, addr)
                print(f"[Backup DNS] Query from {addr[0]}:{addr[1]} for '{domain}' -> {target_ip} (TTL: {ttl}s)", flush=True)
            except Exception as ex:
                print(f"[Backup DNS] Failed to parse/respond query from {addr}: {ex}", flush=True)
    except KeyboardInterrupt:
        print("\n[Backup DNS] Shutting down.")
    finally:
        sock.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Backup DNS Server (Script 9)")
    parser.add_argument("--port", type=int, default=53, help="Port to listen on (default 53)")
    parser.add_argument("--ip", default=DEFAULT_IP, help=f"Destination IP (default {DEFAULT_IP})")
    parser.add_argument("--ttl", type=int, default=DEFAULT_TTL, help=f"TTL in seconds (default {DEFAULT_TTL})")
    args = parser.parse_args()

    run_dns_server(port=args.port, target_ip=args.ip, ttl=args.ttl)
