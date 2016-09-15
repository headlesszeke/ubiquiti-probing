#!/usr/bin/env ruby
require 'socket'
require 'timeout'

BROADCAST_ADDR = "255.255.255.255"
BIND_ADDR = "0.0.0.0"
PORT = 10001
IFACE = nil
timeout = 5

def parse(buf)
  arr = buf.unpack("C*")
  magic = arr.shift(2)
  len = arr.shift(2).pack("C*").unpack("n")[0]
  while arr.length >= 3
    case arr.shift(1)[0]
    when 0x01 # mac address
      mac = arr.shift(8)[2,6].map {|i| "%02x" % i}.join(":")
    when 0x02 # mac address + ip address
      tmp = arr.shift(12)
      mac = tmp[2,6].map {|i| "%02x" % i}.join(":")
      ip = tmp[8,4].map{|i| i.to_s}.join(".")
    when 0x03 # version info...seems like model + firmware ver
      tmplen = arr.shift(2).pack("C*").unpack("n")[0]
      ver = arr.shift(tmplen).pack("C*")
    when 0x0b # product name?
      tmplen = arr.shift(2).pack("C*").unpack("n")[0]
      prod = arr.shift(tmplen).pack("C*")
    when 0x0c # friendly name?
      tmplen = arr.shift(2).pack("C*").unpack("n")[0]
      name = arr.shift(tmplen).pack("C*")
    else # unsupported/unknown
      tmplen = arr.shift(2).pack("C*").unpack("n")[0]
      arr.shift(tmplen)
    end
  end
  puts "MAC:\t#{mac}" if mac
  puts "IP:\t#{ip}" if ip
  puts "PROD:\t#{prod}" if prod
  puts "NAME:\t#{name}" if name
  puts "VER:\t#{ver}" if ver
end

# socket setup
socket = UDPSocket.new
socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BINDTODEVICE, IFACE) if IFACE
socket.bind(BIND_ADDR, PORT)

buffer = "\x01\x00\x00\x00"

puts "sending discover request"

socket.send(buffer,0,BROADCAST_ADDR,PORT)

puts "waiting #{timeout} second#{"s" if timeout > 1} for responses..."
puts ""

while true
  begin
    Timeout::timeout(timeout) do
      resp, addr = socket.recvfrom(1024)
      if resp && resp.length > 4 && resp =~ /^\x01\x00\x00/
        puts addr.last.center(21,"-")
        parse(resp)
      end
    end
  rescue Timeout::Error, Interrupt
    break
  end
end

# socket teardown
socket.close

puts "-" * 21
puts "done"
