% Consola: doar "led on" / "led off".
% Plot continuu (fereastra glisanta), fara restart la fiecare perioada.
% Hardware: jumper GPIO25 (DAC) -> GPIO34 (ADC).
% Inchide Serial Monitor. Opreste cu Ctrl+C.

port = "COM12";
baud = 115200;
vRef = 3.3;
adcMax = 4095;
windowSec = 5;

if exist("s", "var") && isvalid(s)
    delete(s);
    clear s
end

s = serialport(port, baud);
configureTerminator(s, "LF");
flush(s);

tAll = [];
vAll = [];

figure;
while true
    linie = strtrim(readline(s));

    if linie == "led on" || linie == "led off"
        disp(linie);
        continue
    end

    parti = split(linie, ",");
    if numel(parti) ~= 2
        continue
    end

    tAll(end + 1, 1) = str2double(parti(1));
    vAll(end + 1, 1) = str2double(parti(2)) * vRef / adcMax;

    tStart = tAll(end) - windowSec;
    keep = tAll >= tStart;
    tAll = tAll(keep);
    vAll = vAll(keep);

    plot(tAll, vAll, "b");
    xlim([max(0, tAll(end) - windowSec), max(windowSec, tAll(end))]);
    ylim([0, vRef]);
    xlabel("t [s]");
    ylabel("ADC [V]");
    title("ADC in timp real (triunghi DAC)");
    grid on;
    drawnow limitrate
end
