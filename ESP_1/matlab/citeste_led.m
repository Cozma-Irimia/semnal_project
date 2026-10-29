% Figura ca in laborator: sinusoida 100 Hz, 1000 esantioane, 1 V varf,
% plus spectrul ADC (varf langa 100 Hz).
% Hardware: jumper GPIO25 (DAC) -> GPIO34 (ADC).
% Inchide Serial Monitor. Opreste cu Ctrl+C.

port = "COM12";
baud = 115200;
n = 1000;

if exist("s", "var") && isvalid(s)
    delete(s);
    clear s
end

s = serialport(port, baud);
configureTerminator(s, "LF");
s.Timeout = 10;
flush(s);
pause(2);
flush(s);

disp("Astept date de pe " + port + "...");

fig = figure("Name", "ESP32 DAC/ADC sine");
while true
    linie = citesteLinie(s);
    if linie == ""
        continue
    end

    if linie == "led on" || linie == "led off"
        disp(linie);
        continue
    end
    if linie ~= "SINE"
        continue
    end

    fs = str2double(citesteLinie(s));
    if ~isfinite(fs) || fs <= 0
        continue
    end

    dacMv = zeros(n, 1);
    adcMv = zeros(n, 1);
    ok = true;
    for i = 1:n
        parti = split(citesteLinie(s), ",");
        if numel(parti) ~= 2
            ok = false;
            break
        end
        dacMv(i) = str2double(parti(1));
        adcMv(i) = str2double(parti(2));
    end
    if ~ok || any(~isfinite(dacMv)) || any(~isfinite(adcMv))
        continue
    end

    dacV = dacMv / 1000;
    adcV = adcMv / 1000;
    tMs = (0:n-1)' / fs * 1000;

    subplot(2, 1, 1);
    plot(tMs, dacV, "r", tMs, adcV, "b");
    xlim([0, 10]);
    ylim([0, 3]);
    grid on;
    xlabel("Time (ms)");
    ylabel("Voltage (V)");
    title("100 Hz sine, 1000 samples, 1 V peak");
    legend("DAC signal", "ADC reading", "Location", "northeast");

    adcAc = adcV - mean(adcV);
    Y = fft(adcAc);
    P = abs(Y) / n;
    P = P(1:n/2+1);
    P(2:end-1) = 2 * P(2:end-1);
    f = fs * (0:(n/2))' / n;

    subplot(2, 1, 2);
    plot(f, P, "b");
    xlim([0, 2000]);
    ylim([0, 1]);
    grid on;
    xlabel("Frequency (Hz)");
    ylabel("Amplitude (V)");
    title("ADC spectrum (should peak near 100 Hz)");
    drawnow;

    disp("ADC min = " + min(adcV) + " V, max = " + max(adcV) + " V");
    if max(adcV) - min(adcV) < 0.4
        disp("ADC nu urmareste DAC. Verifica jumperul GPIO25 -> GPIO34.");
    end
end

function linie = citesteLinie(s)
    try
        raw = readline(s);
    catch
        linie = "";
        return
    end
    if isempty(raw)
        linie = "";
        return
    end
    linie = strtrim(string(raw));
    if ismissing(linie) || strlength(linie) == 0
        linie = "";
    end
end
