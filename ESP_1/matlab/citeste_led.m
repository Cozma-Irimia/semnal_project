% Sinusoida, histograma, DNL/INL. Esantioanele vin criptate AES-128, cu CRC-16.
% Hardware: jumper GPIO25 (DAC) -> GPIO34 (ADC).
% Inchide Serial Monitor inainte de rulare.

port = "COM12";
baud = 115200;
winMs = 50;

if exist("s", "var") && isvalid(s)
    delete(s);
    clear s
end

vechi = findall(0, "Type", "figure");
for k = 1:numel(vechi)
    if vechi(k).Name == "ESP32 Histogram" || vechi(k).Name == "ESP32 DAC/ADC" || vechi(k).Name == "ESP32 Histogram INL/DNL" || vechi(k).Name == "ESP32 INL/DNL" || vechi(k).Name == "ESP32 DFT"
        delete(vechi(k));
    end
end

fig = uifigure("Name", "ESP32 DAC/ADC", "Position", [40 60 1080 780]);
fig.CloseRequestFcn = @(src, ~) inchideFereastra(src);

g = uigridlayout(fig, [1 2]);
g.ColumnWidth = {320, "1x"};
g.Padding = [16 16 16 16];
g.ColumnSpacing = 16;

panou = uipanel(g, "Title", "Stare");

pg = uigridlayout(panou, [19 1]);
pg.RowHeight = {26, 40, 32, 8, 22, 26, 26, 40, 26, 40, 36, 22, 34, 34, 34, 26, 26, "1x", 40};
pg.RowSpacing = 4;
pg.Padding = [16 14 16 14];

uilabel(pg, "Text", "Port   " + port + "    " + baud, "FontSize", 13);
lblLed = uilabel(pg, "Text", "LED   —", "FontSize", 28, "FontWeight", "bold", ...
    "HorizontalAlignment", "center", "FontColor", [0.4 0.4 0.4]);
lamp = uilamp(pg, "Color", [0.75 0.75 0.75]);
uilabel(pg, "Text", "");
uilabel(pg, "Text", "Buffer", "FontWeight", "bold", "FontSize", 14);
lblN = uilabel(pg, "Text", "esantioane   —", "FontSize", 14);
lblFs = uilabel(pg, "Text", "fs              —", "FontSize", 14);
fsRow = uigridlayout(pg, [1 2]);
fsRow.ColumnWidth = {"1x", 90};
fsRow.RowHeight = {"1x"};
fsRow.Padding = [0 0 0 0];
fsRow.ColumnSpacing = 8;
editFs = uieditfield(fsRow, "numeric", "Value", 10000, "Limits", [400 10000], ...
    "ValueDisplayFormat", "%.0f", "FontSize", 14);
uibutton(fsRow, "Text", "Aplica", "FontSize", 14, ...
    "ButtonPushedFcn", @(~, ~) aplicaFs(fig));
lblFin = uilabel(pg, "Text", "f intrare    —", "FontSize", 14);
finRow = uigridlayout(pg, [1 2]);
finRow.ColumnWidth = {"1x", 90};
finRow.RowHeight = {"1x"};
finRow.Padding = [0 0 0 0];
finRow.ColumnSpacing = 8;
editFin = uieditfield(finRow, "numeric", "Value", 100, "Limits", [10 1000], ...
    "ValueDisplayFormat", "%.0f", "FontSize", 14);
uibutton(finRow, "Text", "Aplica", "FontSize", 14, ...
    "ButtonPushedFcn", @(~, ~) aplicaFin(fig));
waveRow = uigridlayout(pg, [1 2]);
waveRow.ColumnWidth = {72, "1x"};
waveRow.RowHeight = {"1x"};
waveRow.Padding = [0 0 0 0];
waveRow.ColumnSpacing = 8;
uilabel(waveRow, "Text", "Semnal", "FontSize", 14);
uidropdown(waveRow, "Items", ["Sine", "Triangle", "Rectangle", "White noise", "Pink noise"], ...
    "ItemsData", [0 1 2 3 4], "Value", 0, "FontSize", 13, ...
    "ValueChangedFcn", @(src, ~) alegeSemnal(fig, src.Value));
uilabel(pg, "Text", "Grafice", "FontWeight", "bold", "FontSize", 14);
uibutton(pg, "Text", "Histograma", "FontSize", 14, ...
    "ButtonPushedFcn", @(~, ~) deschideHist(fig));
uibutton(pg, "Text", "DFT", "FontSize", 14, ...
    "ButtonPushedFcn", @(~, ~) deschideDft(fig));
uibutton(pg, "Text", "INL / DNL", "FontSize", 14, ...
    "ButtonPushedFcn", @(~, ~) deschideInl(fig));
lblCrc = uilabel(pg, "Text", "CRC          —", "FontSize", 14, "FontColor", [0.35 0.35 0.35]);
lblCrcGresite = uilabel(pg, "Text", "CRC gresite  0", "FontSize", 14);
lblStare = uilabel(pg, "Text", "Astept date...", "FontSize", 13, "WordWrap", "on", ...
    "VerticalAlignment", "top");
btnRow = uigridlayout(pg, [1 2]);
btnRow.ColumnWidth = {"1x", "1x"};
btnRow.RowHeight = {"1x"};
btnRow.Padding = [0 0 0 0];
btnRow.ColumnSpacing = 10;
btnStart = uibutton(btnRow, "Text", "Start", "FontSize", 14, "Enable", "off", ...
    "ButtonPushedFcn", @(~, ~) porneste(fig));
btnStop = uibutton(btnRow, "Text", "Opreste", "FontSize", 14, ...
    "ButtonPushedFcn", @(~, ~) opreste(fig));

axTime = uiaxes(g);
title(axTime, "100 Hz sine, 1 V peak");
xlabel(axTime, "Time (ms)");
ylabel(axTime, "Voltage (V)");
grid(axTime, "on");
xlim(axTime, [0 winMs]);
ylim(axTime, [0 3]);
axTime.Layout.Column = 2;

s = serialport(port, baud);
configureTerminator(s, "LF");
s.Timeout = 1;
if ~isvalid(fig)
    delete(s);
    return
end
flush(s);
pause(2);
if ~isvalid(fig)
    delete(s);
    return
end
flush(s);

tm = timer("ExecutionMode", "fixedSpacing", "Period", 0.02, ...
    "TimerFcn", @(~, ~) actualizeaza(fig));
fig.UserData = struct( ...
    "running", true, "s", s, "tm", tm, ...
    "btnStart", btnStart, "btnStop", btnStop, "lblStare", lblStare, ...
    "lblLed", lblLed, "lamp", lamp, "lblN", lblN, "lblFs", lblFs, "editFs", editFs, ...
    "lblFin", lblFin, "editFin", editFin, ...
    "lblCrc", lblCrc, "lblCrcGresite", lblCrcGresite, ...
    "figHist", gobjects(0), "figDft", gobjects(0), "figInl", gobjects(0), ...
    "axTime", axTime, ...
    "lnDac", gobjects(0), "lnAdc", gobjects(0), "lnDft", gobjects(0), ...
    "pendingCodes", zeros(0, 1), "pendingPh0", 0, ...
    "viewCodes", zeros(0, 1), "viewPh0", 0, ...
    "dftCodes", zeros(0, 1), ...
    "hist", zeros(4096, 1), "total", 0, "histDirty", false, "ticks", 0, ...
    "histCoduri", zeros(0, 1), ...
    "histSine", zeros(4096, 1), "totalSine", 0, "sineCoduri", zeros(0, 1), ...
    "fs", 10000, "fIn", 100, "perCiclu", 100, "forma", 0, "crcGresite", 0, ...
    "nWin", round(10000 * winMs / 1000), "winMs", winMs);
curata = onCleanup(@() inchide(s, fig, tm));
start(tm);
configureCallback(s, "terminator", @(src, ~) primesteLinie(src, fig));
writeline(s, "START");

disp("Astept sinusoida de pe " + port + "...");
waitfor(fig);

function primesteLinie(src, fig)
    if ~isvalid(fig)
        return
    end
    linie = citesteLinie(src);
    if linie == "" || ~isvalid(fig)
        return
    end
    ud = fig.UserData;
    if ~isstruct(ud) || ~ud.running
        return
    end

    if linie == "led on" || linie == "led off"
        if linie == "led on"
            ud.lblLed.Text = "LED   ON";
            ud.lblLed.FontColor = [0.0 0.55 0.15];
            ud.lamp.Color = [0.2 0.8 0.2];
        else
            ud.lblLed.Text = "LED   OFF";
            ud.lblLed.FontColor = [0.7 0.15 0.15];
            ud.lamp.Color = [0.85 0.2 0.2];
        end
        return
    end

    if ~startsWith(linie, "W,")
        return
    end
    parti = split(linie, ",");
    if numel(parti) < 8
        return
    end
    fs = str2double(parti(2));
    fIn = str2double(parti(3));
    perCiclu = str2double(parti(4));
    wave = str2double(parti(5));
    phStart = str2double(parti(6));
    crcRx = str2double(parti(7));
    if ~isfinite(fs) || fs <= 0 || ~isfinite(fIn) || fIn <= 0 || ~isfinite(perCiclu) || perCiclu < 4
        marcheazaCrc(fig, false);
        return
    end
    if ~isfinite(wave) || wave < 0 || wave > 4 || ~isfinite(phStart) || ~isfinite(crcRx)
        marcheazaCrc(fig, false);
        return
    end
    cipher = uint8(sscanf(char(parti(8)), "%2x"));
    if numel(cipher) ~= 80
        marcheazaCrc(fig, false);
        return
    end
    antet = [typecast(uint16(fs), "uint8"), typecast(uint16(fIn), "uint8"), ...
        typecast(uint16(perCiclu), "uint8"), typecast(uint16(wave), "uint8"), ...
        typecast(uint32(phStart), "uint8")];
    crcCalc = crc16Ccitt(uint8([antet, cipher(:).']));
    if crcCalc ~= crcRx
        marcheazaCrc(fig, false);
        return
    end
    marcheazaCrc(fig, true);
    plain = aesEcbDecrypt(cipher);
    codes = double(typecast(plain, "uint16"));
    if numel(codes) ~= 40
        return
    end
    adauga(fig, fs, fIn, perCiclu, wave, phStart, codes(:));
end

function marcheazaCrc(fig, corect)
    if ~isvalid(fig)
        return
    end
    ud = fig.UserData;
    if corect
        ud.lblCrc.Text = "CRC          corect";
        ud.lblCrc.FontColor = [0.0 0.45 0.15];
    else
        ud.crcGresite = ud.crcGresite + 1;
        ud.lblCrc.Text = "CRC          incorect";
        ud.lblCrc.FontColor = [0.7 0.15 0.15];
        ud.lblCrcGresite.Text = "CRC gresite  " + ud.crcGresite;
    end
    fig.UserData = ud;
end

function crc = crc16Ccitt(octeti)
    crc = uint16(65535);
    for k = 1:numel(octeti)
        crc = bitxor(crc, bitshift(uint16(octeti(k)), 8));
        for bit = 1:8
            if bitand(crc, uint16(32768)) ~= 0
                crc = bitxor(bitshift(crc, 1), uint16(4129));
            else
                crc = bitshift(crc, 1);
            end
        end
    end
    crc = double(crc);
end

function plain = aesEcbDecrypt(cipherBytes)
    cheie = uint8('ESP32-ADC-KEY-01');
    jbCheie = typecast(cheie(:).', "int8");
    jbDate = typecast(uint8(cipherBytes(:).'), "int8");
    secret = javax.crypto.spec.SecretKeySpec(jbCheie, "AES");
    criptare = javax.crypto.Cipher.getInstance("AES/ECB/NoPadding");
    criptare.init(javax.crypto.Cipher.DECRYPT_MODE, secret);
    raw = double(criptare.doFinal(jbDate));
    raw(raw < 0) = raw(raw < 0) + 256;
    plain = uint8(raw(:));
end

function adauga(fig, fs, fIn, perCiclu, wave, phStart, codes)
    ud = fig.UserData;
    if ~ud.running || isempty(codes)
        return
    end
    wave = round(wave);
    if fs ~= ud.fs || fIn ~= ud.fIn || wave ~= ud.forma
        ud.pendingCodes = zeros(0, 1);
        ud.viewCodes = zeros(0, 1);
        ud.dftCodes = zeros(0, 1);
        ud.hist(:) = 0;
        ud.total = 0;
        ud.histCoduri = zeros(0, 1);
        ud.editFs.Value = fs;
        ud.editFin.Value = fIn;
    end
    if wave == 0 && (fs ~= ud.fs || fIn ~= ud.fIn || wave ~= ud.forma)
        ud.histSine(:) = 0;
        ud.totalSine = 0;
        ud.sineCoduri = zeros(0, 1);
    end
    ud.fs = fs;
    ud.fIn = fIn;
    ud.forma = wave;
    ud.perCiclu = perCiclu;
    ud.nWin = max(20, round(fs * ud.winMs / 1000));
    if isempty(ud.pendingCodes)
        ud.pendingPh0 = phStart;
        ud.pendingCodes = codes;
    else
        expected = ud.pendingPh0 + numel(ud.pendingCodes);
        if abs(phStart - expected) > 0.5
            ud.pendingCodes = codes;
            ud.pendingPh0 = phStart;
            ud.viewCodes = zeros(0, 1);
        else
            ud.pendingCodes = [ud.pendingCodes; codes];
        end
    end
    if numel(ud.pendingCodes) > 8000
        drop = numel(ud.pendingCodes) - 4000;
        ud.pendingCodes(1:drop) = [];
        ud.pendingPh0 = ud.pendingPh0 + drop;
    end
    c = round(codes);
    c = c(c >= 0 & c <= 4095);
    if ~isempty(c)
        [ud.hist, ud.histCoduri] = adaugaInel(ud.hist, ud.histCoduri, c, 10000);
        if wave == 0
            [ud.histSine, ud.sineCoduri] = adaugaInel(ud.histSine, ud.sineCoduri, c, 10000);
        end
    end
    ud.total = numel(ud.histCoduri);
    if wave == 0
        ud.totalSine = numel(ud.sineCoduri);
    end
    ud.histDirty = true;
    ud.dftCodes = [ud.dftCodes; codes];
    if numel(ud.dftCodes) > 2048
        ud.dftCodes = ud.dftCodes(end - 2047:end);
    end
    fig.UserData = ud;
end

function [histCounts, ring] = adaugaInel(histCounts, ring, noi, limita)
    ring = [ring; noi];
    extra = numel(ring) - limita;
    if extra > 0
        vechi = ring(1:extra);
        ring(1:extra) = [];
        histCounts = histCounts - accumarray(vechi + 1, 1, [4096, 1]);
        histCounts(histCounts < 0) = 0;
    end
    histCounts = histCounts + accumarray(noi + 1, 1, [4096, 1]);
end

function actualizeaza(fig)
    if ~isvalid(fig)
        return
    end
    ud = fig.UserData;
    if ~isstruct(ud) || ~ud.running || isempty(ud.pendingCodes)
        return
    end
        backlog = numel(ud.pendingCodes);
        n = min(backlog, max(8, ceil(backlog / 4)));
        chunk = ud.pendingCodes(1:n);
        ph0 = ud.pendingPh0;
        ud.pendingCodes(1:n) = [];
        ud.pendingPh0 = ph0 + n;
        if isempty(ud.viewCodes)
            ud.viewCodes = chunk;
            ud.viewPh0 = ph0;
        else
            ud.viewCodes = [ud.viewCodes; chunk];
            extra = numel(ud.viewCodes) - ud.nWin;
            if extra > 0
                ud.viewCodes(1:extra) = [];
                ud.viewPh0 = ud.viewPh0 + extra;
            end
        end
        view = ud.viewCodes;
        viewPh = ud.viewPh0;
        fs = ud.fs;
        fIn = ud.fIn;
        per = ud.perCiclu;
        forma = ud.forma;
        win = ud.winMs;
        dftCodes = ud.dftCodes;
        ud.ticks = ud.ticks + 1;
        desenHist = ud.histDirty && mod(ud.ticks, 5) == 0;
        desenDft = mod(ud.ticks, 5) == 0;
        if desenHist
            ud.histDirty = false;
        end
        fig.UserData = ud;

        idx = viewPh + (0:numel(view) - 1)';
        adcV = view * 3.3 / 4095;
        nume = ["sine", "triangle", "rectangle", "white noise", "pink noise"];
        if forma >= 3
            dacV = nan(size(adcV));
            titlu = nume(forma + 1);
        else
            lag = 0;
            if numel(view) >= 16 && max(adcV) - min(adcV) >= 0.2
                lag = cautaDefazaj(idx, adcV, per, forma);
            end
            dacV = semnalComandat(idx - lag, per, forma);
            titlu = fIn + " Hz " + nume(forma + 1) + ", 1 V peak";
        end
        tMs = (0:numel(view) - 1)' / fs * 1000;
        if isempty(ud.lnAdc) || ~isgraphics(ud.lnAdc)
            ud.lnDac = plot(ud.axTime, tMs, dacV, "r");
            hold(ud.axTime, "on");
            ud.lnAdc = plot(ud.axTime, tMs, adcV, "b");
            hold(ud.axTime, "off");
            grid(ud.axTime, "on");
            xlabel(ud.axTime, "Time (ms)");
            ylabel(ud.axTime, "Voltage (V)");
            ylim(ud.axTime, [0 3]);
        else
            set(ud.lnDac, "XData", tMs, "YData", dacV);
            set(ud.lnAdc, "XData", tMs, "YData", adcV);
        end
        xlim(ud.axTime, [0, win]);
        ylim(ud.axTime, [0 3]);
        title(ud.axTime, titlu);

        ud2 = fig.UserData;
        ud2.lnDac = ud.lnDac;
        ud2.lnAdc = ud.lnAdc;
        if ~isfield(ud2, "legForma") || ud2.legForma ~= forma
            if forma >= 3
                legend(ud2.axTime, ud2.lnAdc, "ADC reading", "Location", "northeast");
            else
                legend(ud2.axTime, [ud2.lnDac, ud2.lnAdc], ["DAC signal", "ADC reading"], ...
                    "Location", "northeast");
            end
            ud2.legForma = forma;
        end
        fig.UserData = ud2;
        ud2.lblN.Text = "esantioane   " + ud2.total;
        ud2.lblFs.Text = "fs              " + fs + " Hz";
        ud2.lblFin.Text = "f intrare    " + fIn + " Hz";
        if desenHist
            deseneazaHist(ud2);
            deseneazaInl(ud2);
        end
        if desenDft
            lnDft = deseneazaDft(ud2, dftCodes, fs);
            ud3 = fig.UserData;
            ud3.lnDft = lnDft;
            fig.UserData = ud3;
        end
        drawnow limitrate
end

function lag = cautaDefazaj(idx, adcV, per, forma)
    adc0 = adcV - mean(adcV);
    maxLag = floor(per / 2);
    lag = 0;
    bestC = -inf;
    for k = -maxLag:maxLag
        ref = semnalComandat(idx - k, per, forma);
        ref0 = ref - mean(ref);
        if sum(ref0 .* ref0) < 1e-12
            continue
        end
        c = sum(adc0 .* ref0);
        if c > bestC
            bestC = c;
            lag = k;
        end
    end
end

function y = semnalComandat(pozitie, per, forma)
    faza = mod(pozitie, per) ./ per;
    switch forma
        case 0
            y = 1.5 + sin(2 * pi * faza);
        case 1
            tri = -1 + 4 * faza;
            tri(faza >= 0.5) = 3 - 4 * faza(faza >= 0.5);
            y = 1.5 + tri;
        otherwise
            y = 0.5 * ones(size(faza));
            y(faza < 0.5) = 2.5;
    end
end

function ln = deseneazaDft(ud, codes, fs)
    ln = ud.lnDft;
    if ~esteDeschisa(ud.figDft)
        return
    end
    ax = ud.axDft;
    nfft = 2 ^ floor(log2(max(numel(codes), 1)));
    if nfft < 256 || ~isfinite(fs) || fs <= 0
        if ~isempty(ln) && isgraphics(ln)
            set(ln, "XData", nan, "YData", nan);
        end
        ud.lblDftStare.Text = "Se aduna esantioane pentru DFT.";
        ud.lblDftStare.FontColor = [0.25 0.25 0.25];
        return
    end
    x = codes(end - nfft + 1:end) * 3.3 / 4095;
    x = x - mean(x);
    k = (0:nfft - 1)';
    w = 0.5 - 0.5 * cos(2 * pi * k / nfft);
    y = fft(x .* w);
    half = abs(y(1:nfft / 2 + 1)) / sum(w);
    half(2:end - 1) = 2 * half(2:end - 1);
    magDb = 20 * log10(max(half, 1e-6));
    f = (0:nfft / 2)' * fs / nfft;
    if isempty(ln) || ~isgraphics(ln)
        ln = plot(ax, f, magDb, "b");
    else
        set(ln, "XData", f, "YData", magDb);
    end
    grid(ax, "on");
    xlabel(ax, "Frequency (Hz)");
    ylabel(ax, "Magnitude (dB)");
    title(ax, "ADC DFT");
    xlim(ax, [0, fs / 2]);
    ylim(ax, [-120 10]);
    [nivel, loc] = max(magDb(2:end));
    ud.lblDftFs.Text = "fs              " + fs + " Hz";
    ud.lblDftN.Text = "esantioane   " + nfft;
    ud.lblDftF.Text = "varf           " + sprintf("%.1f Hz", f(loc + 1));
    ud.lblDftDb.Text = "nivel          " + sprintf("%.1f dB", nivel);
    ud.lblDftStare.Text = "DFT este actualizata.";
    ud.lblDftStare.FontColor = [0.0 0.45 0.15];
end

function deseneazaHist(ud)
    i1 = find(ud.hist > 0, 1, "first");
    if isempty(i1)
        return
    end
    i2 = find(ud.hist > 0, 1, "last");
    code1 = i1 - 1;
    code2 = i2 - 1;
    vmin = code1 * 3.3 / 4095;
    vmax = code2 * 3.3 / 4095;
    if ud.running && ud.total > 400 && (vmax - vmin) < 0.4
        ud.lblStare.Text = "ADC nu urmareste DAC. Verifica jumperul GPIO25 -> GPIO34.";
        ud.lblStare.FontColor = [0.7 0.15 0.15];
    elseif ud.running && startsWith(string(ud.lblStare.Text), "ADC nu urmareste")
        ud.lblStare.Text = "Date actualizate.";
        ud.lblStare.FontColor = [0.0 0.45 0.15];
    end
    if ~esteDeschisa(ud.figHist)
        return
    end
    counts = ud.hist(i1:i2);
    edges = (code1 - 0.5):(code2 + 0.5);
    histogram(ud.axHist, "BinEdges", edges, "BinCounts", counts(:), ...
        "FaceColor", [0.2 0.45 0.75], "EdgeColor", "none");
    xlim(ud.axHist, [edges(1), edges(end)]);
    grid(ud.axHist, "on");
    xlabel(ud.axHist, "ADC code");
    ylabel(ud.axHist, "Count");
    title(ud.axHist, "ADC code histogram");
    ud.lblHistN.Text = "esantioane   " + ud.total;
    ud.lblAdcMin.Text = "min          " + sprintf("%.2f V", vmin);
    ud.lblAdcMax.Text = "max         " + sprintf("%.2f V", vmax);
    ud.lblCoduri.Text = "coduri       " + nnz(ud.hist);
    if ud.total >= 10000
        ud.lblHistStare.Text = "Ultimele 10000 esantioane.";
    else
        ud.lblHistStare.Text = "Histograma este actualizata.";
    end
    ud.lblHistStare.FontColor = [0.0 0.45 0.15];
end

function deseneazaInl(ud)
    if ~esteDeschisa(ud.figInl)
        return
    end
    if ud.forma ~= 0
        ud.lblInlStare.Text = "Alege Sine. INL si DNL folosesc doar sinusoida.";
        ud.lblInlStare.FontColor = [0.55 0.30 0.05];
        return
    end
    ud.lblSineN.Text = "esantioane   " + ud.totalSine;
    i1 = find(ud.histSine > 0, 1, "first");
    if isempty(i1)
        ud.lblInlStare.Text = "Astept sinusoida...";
        ud.lblInlStare.FontColor = [0.25 0.25 0.25];
        return
    end
    i2 = find(ud.histSine > 0, 1, "last");
    counts = ud.histSine(i1:i2);
    code1 = i1 - 1;
    code2 = i2 - 1;
    edges = (code1 - 0.5):(code2 + 0.5);
    histogram(ud.axSine, "BinEdges", edges, "BinCounts", counts(:), ...
        "FaceColor", [0.2 0.45 0.75], "EdgeColor", "none");
    xlim(ud.axSine, [edges(1), edges(end)]);
    grid(ud.axSine, "on");
    xlabel(ud.axSine, "ADC code");
    ylabel(ud.axSine, "Count");
    title(ud.axSine, "Sine code histogram");
    ud.lblSineMin.Text = "cod min      " + code1;
    ud.lblSineMax.Text = "cod max      " + code2;

    [codes, dnl, inl] = calculeazaInlDnl(ud.histSine);
    if isempty(dnl)
        ud.lblDnl.Text = "DNL max      —";
        ud.lblInl.Text = "INL max      —";
        ud.lblInlStare.Text = "Sinusoida ruleaza. Se aduna coduri pentru INL si DNL.";
        ud.lblInlStare.FontColor = [0.0 0.45 0.15];
        return
    end
    plot(ud.axDnl, codes, dnl, "b");
    hold(ud.axDnl, "on");
    plot(ud.axDnl, [codes(1) codes(end)], [0 0], "k:");
    hold(ud.axDnl, "off");
    grid(ud.axDnl, "on");
    xlabel(ud.axDnl, "ADC code");
    ylabel(ud.axDnl, "DNL (LSB)");
    title(ud.axDnl, "DNL");

    plot(ud.axInl, codes, inl, "r");
    hold(ud.axInl, "on");
    plot(ud.axInl, [codes(1) codes(end)], [0 0], "k:");
    hold(ud.axInl, "off");
    grid(ud.axInl, "on");
    xlabel(ud.axInl, "ADC code");
    ylabel(ud.axInl, "INL (LSB)");
    title(ud.axInl, "INL");

    ud.lblDnl.Text = "DNL max      " + sprintf("%.3f LSB", max(abs(dnl)));
    ud.lblInl.Text = "INL max      " + sprintf("%.3f LSB", max(abs(inl)));
    ud.lblInlStare.Text = "DNL si INL sunt actualizate din sinusoida.";
    ud.lblInlStare.FontColor = [0.0 0.45 0.15];
end

function [codes, dnl, inl] = calculeazaInlDnl(histCounts)
    codes = [];
    dnl = [];
    inl = [];
    ocupate = find(histCounts > 0);
    if numel(ocupate) < 2
        return
    end
    codMinim = ocupate(1) - 1;
    codMaxim = ocupate(end) - 1;
    if codMaxim - codMinim < 4
        return
    end

    interior = (codMinim + 1:codMaxim - 1)';
    centru = (codMinim + codMaxim) / 2;
    amplitudine = (codMaxim - codMinim) / 2;
    margineJos = (interior - 0.5 - centru) / amplitudine;
    margineSus = (interior + 0.5 - centru) / amplitudine;
    margineJos = min(1, max(-1, margineJos));
    margineSus = min(1, max(-1, margineSus));
    numarEsantioane = sum(histCounts);
    ideal = numarEsantioane / pi * (asin(margineSus) - asin(margineJos));
    ideal = max(ideal, eps);
    dnl = histCounts(interior + 1) ./ ideal - 1;
    inl = cumsum(dnl);
    inl = inl - linspace(inl(1), inl(end), numel(inl))';
    codes = interior;
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

function aplicaFs(fig)
    if ~isvalid(fig)
        return
    end
    ud = fig.UserData;
    val = round(ud.editFs.Value / 100) * 100;
    val = min(10000, max(400, val));
    ud.editFs.Value = val;
    ud.lblStare.Text = "Fs setat la " + val + " Hz.";
    ud.lblStare.FontColor = [0.15 0.15 0.15];
    fig.UserData = ud;
    trimiteComanda(fig, "FS," + val);
end

function alegeSemnal(fig, val)
    if ~isvalid(fig)
        return
    end
    ud = fig.UserData;
    nume = ["Sine", "Triangle", "Rectangle", "White noise", "Pink noise"];
    v = round(double(val));
    if ~isfinite(v) || v < 0 || v > 4
        return
    end
    ud.lblStare.Text = "Semnal: " + nume(v + 1) + ".";
    ud.lblStare.FontColor = [0.15 0.15 0.15];
    fig.UserData = ud;
    trimiteComanda(fig, "WAVE," + v);
end

function aplicaFin(fig)
    if ~isvalid(fig)
        return
    end
    ud = fig.UserData;
    val = round(ud.editFin.Value);
    val = min(1000, max(10, val));
    ud.editFin.Value = val;
    ud.lblStare.Text = "Frecventa de intrare setata la " + val + " Hz.";
    ud.lblStare.FontColor = [0.15 0.15 0.15];
    fig.UserData = ud;
    trimiteComanda(fig, "FIN," + val);
end

function deschideHist(fig)
    if ~isvalid(fig)
        return
    end
    ud = fig.UserData;
    if esteDeschisa(ud.figHist)
        figure(ud.figHist);
        deseneazaHist(ud);
        return
    end
    figHist = uifigure("Name", "ESP32 Histogram", "Position", [160 140 900 540]);
    figHist.CloseRequestFcn = @(src, ~) delete(src);
    gh = uigridlayout(figHist, [1 2]);
    gh.ColumnWidth = {260, "1x"};
    gh.Padding = [16 16 16 16];
    gh.ColumnSpacing = 16;
    panouHist = uipanel(gh, "Title", "Histograma");
    ph = uigridlayout(panouHist, [6 1]);
    ph.RowHeight = {22, 26, 26, 26, 26, "1x"};
    ph.RowSpacing = 4;
    ph.Padding = [16 14 16 14];
    uilabel(ph, "Text", "ADC", "FontWeight", "bold", "FontSize", 14);
    lblHistN = uilabel(ph, "Text", "esantioane   —", "FontSize", 14);
    lblAdcMin = uilabel(ph, "Text", "min          —", "FontSize", 14);
    lblAdcMax = uilabel(ph, "Text", "max         —", "FontSize", 14);
    lblCoduri = uilabel(ph, "Text", "coduri       —", "FontSize", 14);
    lblHistStare = uilabel(ph, "Text", "Astept date...", "FontSize", 13, "WordWrap", "on", ...
        "VerticalAlignment", "top");
    axHist = uiaxes(gh);
    title(axHist, "ADC code histogram");
    xlabel(axHist, "ADC code");
    ylabel(axHist, "Count");
    grid(axHist, "on");
    ud = fig.UserData;
    ud.figHist = figHist;
    ud.lblHistN = lblHistN;
    ud.lblAdcMin = lblAdcMin;
    ud.lblAdcMax = lblAdcMax;
    ud.lblCoduri = lblCoduri;
    ud.lblHistStare = lblHistStare;
    ud.axHist = axHist;
    fig.UserData = ud;
    deseneazaHist(ud);
end

function deschideDft(fig)
    if ~isvalid(fig)
        return
    end
    ud = fig.UserData;
    if esteDeschisa(ud.figDft)
        figure(ud.figDft);
        lnDft = deseneazaDft(ud, ud.dftCodes, ud.fs);
        ud2 = fig.UserData;
        ud2.lnDft = lnDft;
        fig.UserData = ud2;
        return
    end
    figDft = uifigure("Name", "ESP32 DFT", "Position", [200 80 920 500]);
    figDft.CloseRequestFcn = @(src, ~) delete(src);
    gd = uigridlayout(figDft, [1 2]);
    gd.ColumnWidth = {260, "1x"};
    gd.Padding = [16 16 16 16];
    gd.ColumnSpacing = 16;
    panouDft = uipanel(gd, "Title", "DFT");
    pd = uigridlayout(panouDft, [6 1]);
    pd.RowHeight = {22, 26, 26, 26, 26, "1x"};
    pd.RowSpacing = 4;
    pd.Padding = [16 14 16 14];
    uilabel(pd, "Text", "Spectru", "FontWeight", "bold", "FontSize", 14);
    lblDftFs = uilabel(pd, "Text", "fs              —", "FontSize", 14);
    lblDftN = uilabel(pd, "Text", "esantioane   —", "FontSize", 14);
    lblDftF = uilabel(pd, "Text", "varf           —", "FontSize", 14);
    lblDftDb = uilabel(pd, "Text", "nivel          —", "FontSize", 14);
    lblDftStare = uilabel(pd, "Text", "Astept date...", "FontSize", 13, "WordWrap", "on", ...
        "VerticalAlignment", "top");
    axDft = uiaxes(gd);
    title(axDft, "ADC DFT");
    xlabel(axDft, "Frequency (Hz)");
    ylabel(axDft, "Magnitude (dB)");
    grid(axDft, "on");
    xlim(axDft, [0 5000]);
    ylim(axDft, [-120 10]);
    ud = fig.UserData;
    ud.figDft = figDft;
    ud.lblDftFs = lblDftFs;
    ud.lblDftN = lblDftN;
    ud.lblDftF = lblDftF;
    ud.lblDftDb = lblDftDb;
    ud.lblDftStare = lblDftStare;
    ud.axDft = axDft;
    ud.lnDft = gobjects(0);
    fig.UserData = ud;
    lnDft = deseneazaDft(ud, ud.dftCodes, ud.fs);
    ud2 = fig.UserData;
    ud2.lnDft = lnDft;
    fig.UserData = ud2;
end

function deschideInl(fig)
    if ~isvalid(fig)
        return
    end
    ud = fig.UserData;
    if esteDeschisa(ud.figInl)
        figure(ud.figInl);
        deseneazaInl(ud);
        return
    end
    figInl = uifigure("Name", "ESP32 INL/DNL", "Position", [240 60 1080 680]);
    figInl.CloseRequestFcn = @(src, ~) delete(src);
    gi = uigridlayout(figInl, [1 2]);
    gi.ColumnWidth = {280, "1x"};
    gi.Padding = [16 16 16 16];
    gi.ColumnSpacing = 16;
    panouInl = uipanel(gi, "Title", "INL / DNL");
    pi = uigridlayout(panouInl, [9 1]);
    pi.RowHeight = {22, 26, 26, 26, 8, 22, 26, 26, "1x"};
    pi.RowSpacing = 4;
    pi.Padding = [16 14 16 14];
    uilabel(pi, "Text", "Sinusoida", "FontWeight", "bold", "FontSize", 14);
    lblSineN = uilabel(pi, "Text", "esantioane   —", "FontSize", 14);
    lblSineMin = uilabel(pi, "Text", "cod min      —", "FontSize", 14);
    lblSineMax = uilabel(pi, "Text", "cod max      —", "FontSize", 14);
    uilabel(pi, "Text", "");
    uilabel(pi, "Text", "Liniaritate", "FontWeight", "bold", "FontSize", 14);
    lblDnl = uilabel(pi, "Text", "DNL max      —", "FontSize", 14);
    lblInl = uilabel(pi, "Text", "INL max      —", "FontSize", 14);
    lblInlStare = uilabel(pi, "Text", "Astept sinusoida...", "FontSize", 13, "WordWrap", "on", ...
        "VerticalAlignment", "top");
    dreaptaInl = uigridlayout(gi, [2 2]);
    dreaptaInl.RowSpacing = 12;
    dreaptaInl.ColumnSpacing = 12;
    dreaptaInl.Padding = [0 0 0 0];
    axSine = uiaxes(dreaptaInl);
    title(axSine, "Sine code histogram");
    xlabel(axSine, "ADC code");
    ylabel(axSine, "Count");
    grid(axSine, "on");
    axSine.Layout.Row = 1;
    axSine.Layout.Column = [1 2];
    axDnl = uiaxes(dreaptaInl);
    title(axDnl, "DNL");
    xlabel(axDnl, "ADC code");
    ylabel(axDnl, "DNL (LSB)");
    grid(axDnl, "on");
    axDnl.Layout.Row = 2;
    axDnl.Layout.Column = 1;
    axInl = uiaxes(dreaptaInl);
    title(axInl, "INL");
    xlabel(axInl, "ADC code");
    ylabel(axInl, "INL (LSB)");
    grid(axInl, "on");
    axInl.Layout.Row = 2;
    axInl.Layout.Column = 2;
    ud = fig.UserData;
    ud.figInl = figInl;
    ud.lblSineN = lblSineN;
    ud.lblSineMin = lblSineMin;
    ud.lblSineMax = lblSineMax;
    ud.lblDnl = lblDnl;
    ud.lblInl = lblInl;
    ud.lblInlStare = lblInlStare;
    ud.axSine = axSine;
    ud.axDnl = axDnl;
    ud.axInl = axInl;
    fig.UserData = ud;
    deseneazaInl(ud);
end

function ok = esteDeschisa(fereastra)
    ok = ~isempty(fereastra) && all(isvalid(fereastra));
end

function porneste(fig)
    if ~isvalid(fig)
        return
    end
    ud = fig.UserData;
    try
        configureCallback(ud.s, "off");
    catch
    end
    if isvalid(ud.s)
        flush(ud.s);
    end
    ud.pendingCodes = zeros(0, 1);
    ud.pendingPh0 = 0;
    ud.viewCodes = zeros(0, 1);
    ud.dftCodes = zeros(0, 1);
    ud.hist(:) = 0;
    ud.total = 0;
    ud.histCoduri = zeros(0, 1);
    ud.histSine(:) = 0;
    ud.totalSine = 0;
    ud.sineCoduri = zeros(0, 1);
    if esteDeschisa(ud.figDft)
        if ~isempty(ud.lnDft) && isgraphics(ud.lnDft)
            set(ud.lnDft, "XData", nan, "YData", nan);
        end
        ud.lblDftN.Text = "esantioane   —";
        ud.lblDftF.Text = "varf           —";
        ud.lblDftDb.Text = "nivel          —";
        ud.lblDftStare.Text = "Astept date...";
        ud.lblDftStare.FontColor = [0.25 0.25 0.25];
    end
    if esteDeschisa(ud.figInl)
        cla(ud.axSine);
        cla(ud.axDnl);
        cla(ud.axInl);
        grid(ud.axSine, "on");
        grid(ud.axDnl, "on");
        grid(ud.axInl, "on");
        title(ud.axSine, "Sine code histogram");
        title(ud.axDnl, "DNL");
        title(ud.axInl, "INL");
        ud.lblSineN.Text = "esantioane   —";
        ud.lblSineMin.Text = "cod min      —";
        ud.lblSineMax.Text = "cod max      —";
        ud.lblDnl.Text = "DNL max      —";
        ud.lblInl.Text = "INL max      —";
        ud.lblInlStare.Text = "Astept sinusoida...";
        ud.lblInlStare.FontColor = [0.25 0.25 0.25];
    end
    ud.running = true;
    ud.btnStart.Enable = "off";
    ud.btnStop.Enable = "on";
    ud.lblStare.Text = "Astept date...";
    ud.lblStare.FontColor = [0.15 0.15 0.15];
    fig.UserData = ud;
    trimiteComanda(fig, "START");
end

function trimiteComanda(fig, linie)
    if ~isvalid(fig)
        return
    end
    ud = fig.UserData;
    if ~isstruct(ud) || ~isfield(ud, "s") || ~isvalid(ud.s)
        return
    end
    reia = ud.running;
    try
        configureCallback(ud.s, "off");
    catch
    end
    flush(ud.s);
    ud.pendingCodes = zeros(0, 1);
    ud.pendingPh0 = 0;
    ud.viewCodes = zeros(0, 1);
    ud.dftCodes = zeros(0, 1);
    ud.hist(:) = 0;
    ud.total = 0;
    ud.histCoduri = zeros(0, 1);
    ud.histSine(:) = 0;
    ud.totalSine = 0;
    ud.sineCoduri = zeros(0, 1);
    fig.UserData = ud;
    writeline(ud.s, linie);
    if reia && isvalid(fig)
        configureCallback(ud.s, "terminator", @(src, ~) primesteLinie(src, fig));
    end
end

function opreste(fig)
    if ~isvalid(fig)
        return
    end
    ud = fig.UserData;
    ud.running = false;
    try
        configureCallback(ud.s, "off");
    catch
    end
    ud.btnStart.Enable = "on";
    ud.btnStop.Enable = "off";
    ud.lblStare.Text = "Oprit. Apasa Start pentru a relua.";
    ud.lblStare.FontColor = [0.25 0.25 0.25];
    fig.UserData = ud;
end

function inchideFereastra(fig)
    if ~isvalid(fig)
        return
    end
    ud = fig.UserData;
    try
        if isstruct(ud) && isfield(ud, "s") && isvalid(ud.s)
            configureCallback(ud.s, "off");
        end
    catch
    end
    try
        if isstruct(ud) && isfield(ud, "tm") && isvalid(ud.tm)
            stop(ud.tm);
        end
    catch
    end
    try
        if isstruct(ud)
            inchideDinUserData(ud);
        end
    catch
    end
    delete(fig);
end

function inchide(s, fig, tm)
    extra = gobjects(0);
    try
        if isvalid(fig) && isstruct(fig.UserData)
            extra = ferestreDin(fig.UserData);
        end
    catch
    end
    try
        if isvalid(s)
            configureCallback(s, "off");
            delete(s);
        end
    catch
    end
    try
        if isvalid(tm)
            stop(tm);
            delete(tm);
        end
    catch
    end
    try
        if isvalid(fig)
            delete(fig);
        end
    catch
    end
    try
        inchideLista(extra);
    catch
    end
end

function inchideDinUserData(ud)
    inchideLista(ferestreDin(ud));
end

function figs = ferestreDin(ud)
    figs = gobjects(0);
    nume = {"figHist", "figDft", "figInl"};
    for k = 1:numel(nume)
        if isfield(ud, nume{k}) && esteDeschisa(ud.(nume{k}))
            figs(end + 1) = ud.(nume{k}); %#ok<AGROW>
        end
    end
end

function inchideLista(varargin)
    for k = 1:nargin
        grup = varargin{k};
        for n = 1:numel(grup)
            try
                if isvalid(grup(n))
                    delete(grup(n));
                end
            catch
            end
        end
    end
end
