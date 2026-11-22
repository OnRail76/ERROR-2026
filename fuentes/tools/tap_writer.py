"""Real ZX Spectrum ROM-format TAP with auto-run BASIC + machine code."""
from pathlib import Path
import struct

def block(flag,data):
    payload=bytes([flag])+data
    parity=0
    for byte in payload:parity^=byte
    payload+=bytes([parity])
    return struct.pack('<H',len(payload))+payload

def basic_line(number,tokens):
    payload=tokens+b'\r'
    return struct.pack('>H',number)+struct.pack('<H',len(payload))+payload

def create_tap(code,name,out,origin=32768,extra_blocks=()):
    assert origin==32768 and len(code)<32768
    # CLEAR VAL "32767": LOAD "" CODE: RANDOMIZE USR VAL "32768"
    prog = basic_line(10,b'\xfd \xb0 "32767"')
    for i in range(1 + len(extra_blocks)):
        prog += basic_line(20 + 10*i,b'\xef "" \xaf')
    prog += basic_line(30 + 10*len(extra_blocks),b'\xf9 \xc0 \xb0 "32768"')
    label=name.encode('ascii','replace')[:10].ljust(10,b' ')
    head_bas=bytes([0])+label+struct.pack('<HHH',len(prog),10,len(prog))
    raw=block(0,head_bas)+block(255,prog)
    for address, data in [(origin, code), *extra_blocks]:
        head_cod=bytes([3])+label+struct.pack('<HHH',len(data),address,address)
        raw += block(0,head_cod)+block(255,data)
    Path(out).write_bytes(raw)
    return raw
