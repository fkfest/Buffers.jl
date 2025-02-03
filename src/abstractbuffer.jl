
abstract type AbstractBuffer end

function used(buf::AbstractBuffer)
  return buf.offset[] - 1
end

function reset!(buf::AbstractBuffer)
  buf.offset[] = 1
  return
end
