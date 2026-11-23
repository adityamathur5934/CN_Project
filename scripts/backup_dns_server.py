#!/usr/bin/env python3
"""
Backup DNS Server — Phase 2 Extension A
stdlib only, no external dependencies.

Listens on UDP port 53 and answers A-record queries for *.team1.test.
All other queries receive a REFUSED response so the client can fall back
to a forwarder rather than hanging.

Usage:
    sudo python3 scripts/backup_dns_server.py [EDGE_IP]
    sudo python3 scripts/backup_dns_server.py 10.7.11.31
"""

import sys
import socket
import struct

EDGE_IP = sys.argv[1] if len(sys.argv) > 1 else "10.7.11.31"
TTL = 30
BIND_ADDR = "0.0.0.0"
PORT = 53

QTYPE_A = 1


def parse_question(data):
    """
    Parse the question section of a DNS query starting at offset 12.
    Returns (domain_str, qtype, qclass, end_offset).
    Returns None on malformed input.
    """
    offset = 12
    labels = []
    try:
        while offset < len(data):
            length = data[offset]
            if length == 0:
                offset += 1
                break
            if length & 0xC0:
                # Compression pointer — not expected in a question, bail out
                return None
            offset += 1
            if offset + length > len(data):
                return None
            labels.append(data[offset:offset + length].decode("ascii", errors="replace"))
            offset += length
        if offset + 4 > len(data):
            return None
        qtype, qclass = struct.unpack_from("!HH", data, offset)
        return ".".join(labels), qtype, qclass, offset + 4
    except Exception:
        return None


def build_a_response(query_data, ip_str, ttl):
    """Return a valid DNS A-record response for the query."""
    tx_id = query_data[:2]
    # QR=1 response, Opcode=0, AA=1, TC=0, RD=1, RA=1, RCODE=0 (NOERROR)
    flags = b"\x85\x80"
    # QDCOUNT=1, ANCOUNT=1, NSCOUNT=0, ARCOUNT=0
    counts = b"\x00\x01\x00\x01\x00\x00\x00\x00"

    # Question section: copy from query (from offset 12 to end of question)
    parsed = parse_question(query_data)
    if parsed is None:
        return None
    _, _, _, q_end = parsed
    question = query_data[12:q_end]

    # Answer: pointer to QNAME at offset 12 (0xc00c), type A, class IN
    ans_name = b"\xc0\x0c"
    ans_type = struct.pack("!H", QTYPE_A)
    ans_class = b"\x00\x01"
    ans_ttl = struct.pack("!I", ttl)
    ans_rdata = socket.inet_aton(ip_str)
    ans_rdlen = struct.pack("!H", len(ans_rdata))
    answer = ans_name + ans_type + ans_class + ans_ttl + ans_rdlen + ans_rdata

    return tx_id + flags + counts + question + answer


def build_refused_response(query_data):
    """Return a REFUSED response so the client does not hang waiting."""
    if len(query_data) < 12:
        return None
    tx_id = query_data[:2]
    # QR=1, AA=0, RCODE=5 (REFUSED)
    flags = b"\x80\x05"
    counts = b"\x00\x01\x00\x00\x00\x00\x00\x00"
    parsed = parse_question(query_data)
    if parsed is None:
        return None
    _, _, _, q_end = parsed
    question = query_data[12:q_end]
    return tx_id + flags + counts + question


def main():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        sock.bind((BIND_ADDR, PORT))
    except PermissionError:
        print(f"[!] Cannot bind to port {PORT}. Run with: sudo python3 {sys.argv[0]}")
        sys.exit(1)

    print(f"[*] Backup DNS Server listening on {BIND_ADDR}:{PORT}/UDP")
    print(f"[*] Resolving *.team1.test -> {EDGE_IP}  (TTL {TTL}s)")
    print(f"[*] Press Ctrl+C to stop.\n")

    while True:
        try:
            data, addr = sock.recvfrom(512)
            parsed = parse_question(data)
            if parsed is None:
                print(f"[!] Malformed query from {addr[0]}:{addr[1]} — dropped")
                continue

            domain, qtype, qclass, _ = parsed
            print(f"[+] Query from {addr[0]}:{addr[1]}  type={qtype}  '{domain}'")

            if "team1.test" in domain and qtype == QTYPE_A:
                resp = build_a_response(data, EDGE_IP, TTL)
                if resp:
                    sock.sendto(resp, addr)
                    print(f"    -> A {EDGE_IP}  TTL {TTL}s")
                else:
                    print(f"    -> Failed to build response (malformed query)")
            else:
                resp = build_refused_response(data)
                if resp:
                    sock.sendto(resp, addr)
                print(f"    -> REFUSED (not *.team1.test A query)")

        except KeyboardInterrupt:
            print("\n[*] Backup DNS Server stopped.")
            break
        except Exception as e:
            print(f"[!] Error: {e}")

    sock.close()


if __name__ == "__main__":
    main()
