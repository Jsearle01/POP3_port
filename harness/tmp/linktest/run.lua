local out=io.open("harness/tmp/linktest/run.log","w")
local function L(s) out:write(s.."\n"); out:flush() end
local cpu=manager.machine.devices[":maincpu"]; local mem=cpu.spaces["program"]
local scr=manager.machine.screens:at(1)
local function decb(p)
  local f=io.open(p,"rb"); local d=f:read("*a"); f:close(); local i,ex=1,nil
  while i<=#d do local t=string.byte(d,i)
    if t==0 then local n=string.byte(d,i+1)*256+string.byte(d,i+2)
      local a=string.byte(d,i+3)*256+string.byte(d,i+4)
      for j=0,n-1 do mem:write_u8(a+j,string.byte(d,i+5+j)) end; i=i+5+n
    elseif t==0xFF then ex=string.byte(d,i+3)*256+string.byte(d,i+4); break else break end end
  return ex end
local st,mark="boot",0
_G._n=emu.add_machine_frame_notifier(function()
  local fn=scr:frame_number()
  if st=="boot" and fn>=300 and cpu.state["PC"].value>=0x8000 then
    mem:write_u8(0x0400,0x00); mem:write_u8(0x0401,0x00)   -- clear both targets first
    local ex=decb("harness/tmp/linktest/linked2.bin")
    L("loaded, exec=$"..string.format("%04X",ex)); cpu.state["PC"].value=ex; st="run"; mark=fn
  elseif st=="run" and fn>=mark+60 then
    local a,b=mem:read_u8(0x0400),mem:read_u8(0x0401)
    L(string.format("$0400 = $%02X  (want $A5 — written by foo, the LINKED-IN module)",a))
    L(string.format("$0401 = $%02X  (want $5A — written after foo RETURNED)",b))
    L((a==0xA5 and b==0x5A) and "VERDICT: PASS — cross-module call executed and returned"
                            or "VERDICT: FAIL")
    out:close(); manager.machine:exit()
  end
end)
