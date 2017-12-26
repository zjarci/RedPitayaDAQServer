export RedPitayaCluster, master, readDataPeriods

import Base: length

mutable struct RedPitayaCluster
  rp::Vector{RedPitaya}
end

#TODO: set first RP to master
function RedPitayaCluster(hosts::Vector{String}, port=5025)
  rp = RedPitaya[ RedPitaya(host, port) for host in hosts ]

  return RedPitayaCluster(rp)
end

length(rpc::RedPitayaCluster) = length(rpc.rp)

master(rpc::RedPitayaCluster) = rpc.rp[1]

function currentFrame(rpc::RedPitayaCluster)
  currentFrames = [ currentFrame(rp) for rp in rpc.rp ]
  println("Current frame: $currentFrames")
  return minimum(currentFrames)
end

function currentPeriod(rpc::RedPitayaCluster)
  currentPeriods = [ currentPeriod(rp) for rp in rpc.rp ]
  println("Current frame: $currentPeriod")
  return minimum(currentPeriods)
end

for op in [:periodsPerFrame,  :samplesPerPeriod, :decimation]
  @eval $op(rpc::RedPitayaCluster) = $op(master(rpc))
  @eval begin
    function $op(rpc::RedPitayaCluster, value)
      for rp in rpc.rp
        $op(rp, value)
      end
    end
  end
end

for op in [:connectADC,  :startADC, :stopADC, :disconnect, :connect]
  @eval begin
    function $op(rpc::RedPitayaCluster)
      for rp in rpc.rp
        $op(rp)
      end
    end
  end
end

masterTrigger(rpc::RedPitayaCluster, val::Bool) = masterTrigger(master(rpc), val)

# "TRIGGERED" or "CONTINUOUS"
function ramWriterMode(rpc::RedPitayaCluster, mode::String)
  for rp in rpc.rp
    ramWriterMode(rp, mode)
  end
end

for op in [:amplitudeDAC,  :frequencyDAC, :phaseDAC, :modulusFactorDAC, :modulusDAC]
  @eval function $op(rpc::RedPitayaCluster, chan::Integer, component::Integer)
    idxRP = div(chan-1, 2) + 1
    chanRP = mod1(chan, 2)
    return $op(rpc.rp[idxRP], chanRP, component)
  end
  @eval function $op(rpc::RedPitayaCluster, chan::Integer, component::Integer, value)
    idxRP = div(chan-1, 2) + 1
    chanRP = mod1(chan, 2)
    return $op(rpc.rp[idxRP], chanRP, component, value)
  end
end

function setSlowDAC(rpc::RedPitayaCluster, chan, value)
  idxRP = div(chan-1, 2) + 1
  chanRP = mod1(chan, 2)
  setSlowDAC(rpc.rp[idxRP], chanRP, value)
end

function getSlowADC(rpc::RedPitayaCluster, chan::Integer)
  idxRP = div(chan-1, 2) + 1
  chanRP = mod1(chan, 2)
  getSlowADC(rpc.rp[idxRP], chanRP)
end

#"STANDARD" or "RASTERIZED"
modeDAC(rpc::RedPitayaCluster) = modeDAC(master(rpc))

function modeDAC(rpc::RedPitayaCluster, mode::String)
  for rp in rpc.rp
    modeDAC(rp, mode)
  end
end


# High level read. numFrames can adress a future frame. Data is read in
# chunks
function readData(rpc::RedPitayaCluster, startFrame, numFrames)
  dec = master(rpc).decimation
  numSampPerPeriod = master(rpc).samplesPerPeriod
  numSamp = numSampPerPeriod * numFrames
  numPeriods = master(rpc).periodsPerFrame
  numSampPerFrame = numSampPerPeriod * numPeriods
  numRP = length(rpc)

  data = zeros(Int16, numSampPerPeriod, 2*numRP, numPeriods, numFrames)
  wpRead = startFrame
  l=1

  # This is a wild guess for a good chunk size
  chunkSize = max(1,  round(Int, 1000000 / numSampPerFrame)  )
  println("chunkSize = $chunkSize")
  while l<=numFrames
    wpWrite = currentFrame(rpc)
    while wpRead >= wpWrite # Wait that startFrame is reached
      wpWrite = currentFrame(rpc)
      println(wpWrite)
    end
    chunk = min(wpWrite-wpRead,chunkSize) # Determine how many frames to read
    println(chunk)
    if l+chunk > numFrames
      chunk = numFrames - l + 1
    end

    println("Read from $wpRead until $(wpRead+chunk-1), WpWrite $(wpWrite), chunk=$(chunk)")

    for (d,rp) in enumerate(rpc.rp)
      u = readData_(rp, Int64(wpRead), Int64(chunk))

      data[:,2*d-1,:,l:(l+chunk-1)] = u[1,:,:,:]
      data[:,2*d,:,l:(l+chunk-1)] = u[2,:,:,:]
    end

    l += chunk
    wpRead += chunk
  end

  return data
end

function readDataPeriods(rpc::RedPitayaCluster, startPeriod, numPeriods)
  dec = master(rpc).decimation
  numSampPerPeriod = master(rpc).samplesPerPeriod
  numSamp = numSampPerPeriod * numPeriods
  numRP = length(rpc)

  data = zeros(Int16, numSampPerPeriod, 2*numRP, numPeriods)
  wpRead = startPeriod
  l=1

  # This is a wild guess for a good chunk size
  chunkSize = max(1,  round(Int, 1000000 / numSampPerPeriod)  )
  println("chunkSize = $chunkSize; numPeriods = $numPeriods")
  while l<=numPeriods
    wpWrite = currentPeriod(rpc)
    while wpRead >= wpWrite # Wait that startPeriod is reached
      wpWrite = currentPeriod(rpc)
      println(wpWrite)
    end
    chunk = min(wpWrite-wpRead,chunkSize) # Determine how many periods to read
    println(chunk)
    if l+chunk > numPeriods
      chunk = numPeriods - l + 1
    end

    println("Read from $wpRead until $(wpRead+chunk-1), WpWrite $(wpWrite), chunk=$(chunk)")

    for (d,rp) in enumerate(rpc.rp)
      u = readDataPeriods_(rp, Int64(wpRead), Int64(chunk))

      data[:,2*d-1,l:(l+chunk-1)] = u[1,:,:]
      data[:,2*d,l:(l+chunk-1)] = u[2,:,:]
    end

    l += chunk
    wpRead += chunk
  end

  return data
end