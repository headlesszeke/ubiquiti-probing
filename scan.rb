#!/usr/bin/env ruby
require 'socket'
require 'timeout'

class String
  def hexdump
    start = 0
    finish = nil
    counter = 0
    ascii = ""
    hex = "|"
    self.each_byte do |c|
      if counter >= start
        hex << "%02x " % c
        ascii << (c.between?(32, 126) ? c : ?.)
      end
      break if finish && finish <= counter
      counter += 1
    end
    hex.chomp!(" ")
    hex << "|" + ascii + "|"
    return hex
  end
end

BROADCAST_ADDR = "255.255.255.255"
BIND_ADDR = "0.0.0.0"
PORT = 10001
IFACE = nil
timeout = 5

def parse(buf)
  arr = buf.unpack("C*")
  magic = arr.shift(2)
  len = arr.shift(2).pack("C*").unpack("n")[0]
  unknown = []
  while arr.length >= 3
    type = arr.shift(1)[0]
    case type
    when 0x01 # mac address
      mac = arr.shift(8)[2,6].map {|i| "%02x" % i}.join(":")
    when 0x02 # mac address + ip address
      tmp = arr.shift(12)
      mac = tmp[2,6].map {|i| "%02x" % i}.join(":")
      ip = tmp[8,4].map{|i| i.to_s}.join(".")
    when 0x03 # version info...seems like model + firmware ver
      tmplen = arr.shift(2).pack("C*").unpack("n")[0]
      ver = arr.shift(tmplen).pack("C*")
    when 0x0a # uptime
      tmplen = arr.shift(2).pack("C*").unpack("n")[0]
      uptime = arr.shift(tmplen).pack("C*").unpack("N")[0]
      days = uptime/86400
      hrs = uptime/3600%24
      mins = uptime/60%60
      secs = uptime%60
    when 0x0b # hostname
      tmplen = arr.shift(2).pack("C*").unpack("n")[0]
      name = arr.shift(tmplen).pack("C*")
    when 0x0c # product name
      tmplen = arr.shift(2).pack("C*").unpack("n")[0]
      prod = arr.shift(tmplen).pack("C*")
    else # unsupported/unknown
      str = "type:0x%02x " % type
      tmplen = arr.shift(2).pack("C*").unpack("n")[0]
      str << "data:#{arr.shift(tmplen).pack("C*").hexdump}"
      unknown << str
    end
  end
  puts "MAC:      #{mac}" if mac
  puts "IP:       #{ip}" if ip
  puts "HOSTNAME: #{name}" if name
  puts "PRODUCT:  #{prod}" if prod
  puts "VERSION:  #{ver}" if ver
  puts "UPTIME:   %02d:%02d:%02d:%02d" % [days,hrs,mins,secs]
  unknown.each {|line| puts "UNKNOWN:  #{line}"}
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
