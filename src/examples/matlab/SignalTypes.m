
% An example for using the server to output different signal types
% Connect the outputs with an oscilloscope!

% Add the client object to the path
addpath('../../client/matlab/')

% Connect to the Red Pitaya
rp = RedPitaya('rp-f00806.local');
rp.connect();

% Define acquisition parameters
dec = 8;
modulus = 4800;
frequency = 25000;
base_frequency = 125000000;
samples_per_period = floor(modulus/dec); %samples_per_period_base/dec
periods_per_frame = 1;

% Set acquisition parameters
rp.setDecimation(dec);
rp.setSamplesPerPeriod(samples_per_period);
rp.setPeriodsPerFrame(periods_per_frame);

rp.setDACMode(0, "standard");
rp.setDACMode(1, "standard");

rp.setAmplitude(0, 0, 7000);
rp.setAmplitude(1, 0, 7000);

rp.setSignalType(0, 'sine');
pause(3);
rp.setSignalType(0, 'dc');
pause(3);
rp.setSignalType(0, 'square');
pause(3);
rp.setSignalType(0, 'triangle');
pause(3);
rp.setSignalType(0, 'sawtooth');
pause(3);
rp.setSignalType(1, 'sine');
pause(3);
rp.setSignalType(1, 'dc');
pause(3);
rp.setSignalType(1, 'square');
pause(3);
rp.setSignalType(1, 'triangle');
pause(3);
rp.setSignalType(1, 'sawtooth');

