% Sinusoida derulata continuu (ultimele 50 ms) si histograma codurilor ADC.
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
    if vechi(k).Name == "ESP32 Histogram" || vechi(k).Name == "ESP32 DAC/ADC" || vechi(k).Name == "ESP32 Histogram INL/DNL"
        delete(vechi(k));
    end
end

fig = uifigure("Name", "ESP32 Histogram", "Position", [60 40 1240 760]);
fig.CloseRequestFcn = @(src, ~) inchideFereastra(src);

g = uigridlayout(fig, [2 2]);
g.ColumnWidth = {320, "1x"};
g.RowHeight = {"1x", "1x"};
g.Padding = [16 16 16 16];
g.RowSpacing = 14;
g.ColumnSpacing = 16;

panou = uipanel(g, "Title", "Stare");
panou.Layout.Row = [1 2];
panou.Layout.Column = 1;

pg = uigridlayout(panou, [14 1]);
pg.RowHeight = {26, 48, 40, 18, 22, 26, 26, 18, 22, 26, 26, 26, "1x", 40};
pg.RowSpacing = 6;
pg.Padding = [16 14 16 14];

uilabel(pg, "Text", "Port   " + port + "    " + baud, "FontSize", 13);
lblLed = uilabel(pg, "Text", "LED   —", "FontSize", 28, "FontWeight", "bold", ...
    "HorizontalAlignment", "center", "FontColor", [0.4 0.4 0.4]);
lamp = uilamp(pg, "Color", [0.75 0.75 0.75]);
uilabel(pg, "Text", "");
uilabel(pg, "Text", "Buffer", "FontWeight", "bold", "FontSize", 14);
lblN = uilabel(pg, "Text", "esantioane   —", "FontSize", 14);
lblFs = uilabel(pg, "Text", "fs              —", "FontSize", 14);
uilabel(pg, "Text", "");
uilabel(pg, "Text", "ADC", "FontWeight", "bold", "FontSize", 14);
lblAdcMin = uilabel(pg, "Text", "min          —", "FontSize", 14);
lblAdcMax = uilabel(pg, "Text", "max         —", "FontSize", 14);
lblCoduri = uilabel(pg, "Text", "coduri       —", "FontSize", 14);
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
axTime.Layout.Row = 1;
axTime.Layout.Column = 2;
title(axTime, "100 Hz sine, 1 V peak");
xlabel(axTime, "Time (ms)");
ylabel(axTime, "Voltage (V)");
grid(axTime, "on");
xlim(axTime, [0 winMs]);
ylim(axTime, [0 3]);

axHist = uiaxes(g);
axHist.Layout.Row = 2;
axHist.Layout.Column = 2;
title(axHist, "ADC code histogram");
xlabel(axHist, "ADC code");
ylabel(axHist, "Count");
grid(axHist, "on");

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
    "lblLed", lblLed, "lamp", lamp, "lblN", lblN, "lblFs", lblFs, ...
    "lblAdcMin", lblAdcMin, "lblAdcMax", lblAdcMax, "lblCoduri", lblCoduri, ...
    "axTime", axTime, "axHist", axHist, "lnDac", gobjects(0), "lnAdc", gobjects(0), ...
    "pendingCodes", zeros(0, 1), "pendingPh0", 0, ...
    "viewCodes", zeros(0, 1), "viewPh0", 0, ...
    "hist", zeros(4096, 1), "total", 0, "histDirty", false, "ticks", 0, ...
    "fs", 4000, "nWin", round(4000 * winMs / 1000), "winMs", winMs);
curata = onCleanup(@() inchide(s, fig, tm));
start(tm);
configureCallback(s, "terminator", @(src, ~) primesteLinie(src, fig));

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
    if numel(parti) < 5
        return
    end
    fs = str2double(parti(2));
    phStart = str2double(parti(3));
    codes = str2double(parti(4:end));
    if ~isfinite(fs) || fs <= 0 || ~isfinite(phStart) || any(~isfinite(codes))
        return
    end
    adauga(fig, fs, phStart, codes(:));
end

function adauga(fig, fs, phStart, codes)
    ud = fig.UserData;
    if ~ud.running || isempty(codes)
        return
    end
    ud.fs = fs;
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
        ud.hist = ud.hist + accumarray(c + 1, 1, [4096, 1]);
    end
    ud.total = ud.total + numel(codes);
    ud.histDirty = true;
    fig.UserData = ud;
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
        win = ud.winMs;
        ud.ticks = ud.ticks + 1;
        desenHist = ud.histDirty && mod(ud.ticks, 5) == 0;
        if desenHist
            ud.histDirty = false;
        end
        fig.UserData = ud;

        idx = viewPh + (0:numel(view) - 1)';
        per = fs / 100;
        dacV = 1.5 + sin(2 * pi * mod(idx, per) / per);
        adcV = view * 3.3 / 4095;
        tMs = idx / fs * 1000;
        if isempty(ud.lnAdc) || ~isgraphics(ud.lnAdc)
            ud.lnDac = plot(ud.axTime, tMs, dacV, "r");
            hold(ud.axTime, "on");
            ud.lnAdc = plot(ud.axTime, tMs, adcV, "b");
            hold(ud.axTime, "off");
            grid(ud.axTime, "on");
            xlabel(ud.axTime, "Time (ms)");
            ylabel(ud.axTime, "Voltage (V)");
            title(ud.axTime, "100 Hz sine, 1 V peak");
            legend(ud.axTime, "DAC signal", "ADC reading", "Location", "northeast");
            ylim(ud.axTime, [0 3]);
        else
            set(ud.lnDac, "XData", tMs, "YData", dacV);
            set(ud.lnAdc, "XData", tMs, "YData", adcV);
        end
        if tMs(end) - tMs(1) < win
            xlim(ud.axTime, [tMs(1), tMs(1) + win]);
        else
            xlim(ud.axTime, [tMs(end) - win, tMs(end)]);
        end
        ylim(ud.axTime, [0 3]);

        ud2 = fig.UserData;
        ud2.lnDac = ud.lnDac;
        ud2.lnAdc = ud.lnAdc;
        fig.UserData = ud2;
        ud2.lblN.Text = "esantioane   " + ud2.total;
        ud2.lblFs.Text = "fs              " + fs + " Hz";
        if desenHist
            deseneazaHist(ud2);
        end
        drawnow limitrate
end

function deseneazaHist(ud)
    i1 = find(ud.hist > 0, 1, "first");
    if isempty(i1)
        return
    end
    i2 = find(ud.hist > 0, 1, "last");
    counts = ud.hist(i1:i2);
    code1 = i1 - 1;
    code2 = i2 - 1;
    edges = (code1 - 0.5):(code2 + 0.5);
    histogram(ud.axHist, "BinEdges", edges, "BinCounts", counts(:), ...
        "FaceColor", [0.2 0.45 0.75], "EdgeColor", "none");
    xlim(ud.axHist, [edges(1), edges(end)]);
    grid(ud.axHist, "on");
    xlabel(ud.axHist, "ADC code");
    ylabel(ud.axHist, "Count");
    title(ud.axHist, "ADC code histogram");

    vmin = code1 * 3.3 / 4095;
    vmax = code2 * 3.3 / 4095;
    ud.lblAdcMin.Text = "min          " + sprintf("%.2f V", vmin);
    ud.lblAdcMax.Text = "max         " + sprintf("%.2f V", vmax);
    ud.lblCoduri.Text = "coduri       " + nnz(ud.hist);
    if ~ud.running
        return
    end
    if ud.total > 400 && (vmax - vmin) < 0.4
        ud.lblStare.Text = "ADC nu urmareste DAC. Verifica jumperul GPIO25 -> GPIO34.";
        ud.lblStare.FontColor = [0.7 0.15 0.15];
    else
        ud.lblStare.Text = "Sinusoida ruleaza. Histograma se actualizeaza.";
        ud.lblStare.FontColor = [0.0 0.45 0.15];
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
    ud.running = true;
    ud.btnStart.Enable = "off";
    ud.btnStop.Enable = "on";
    ud.lblStare.Text = "Astept date...";
    ud.lblStare.FontColor = [0.15 0.15 0.15];
    fig.UserData = ud;
    configureCallback(ud.s, "terminator", @(src, ~) primesteLinie(src, fig));
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
    delete(fig);
end

function inchide(s, fig, tm)
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
end
