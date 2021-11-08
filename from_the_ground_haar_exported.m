classdef from_the_ground_haar_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                     matlab.ui.Figure
        CompressedFilenameEditField  matlab.ui.control.EditField
        FilenameEditField_2Label     matlab.ui.control.Label
        FilenameEditField            matlab.ui.control.EditField
        FilenameEditFieldLabel       matlab.ui.control.Label
        CompressedSizeTextArea       matlab.ui.control.TextArea
        CompressedSizeTextAreaLabel  matlab.ui.control.Label
        CompressButton               matlab.ui.control.Button
        OrignalSizeTextArea          matlab.ui.control.TextArea
        OrignalSizeTextAreaLabel     matlab.ui.control.Label
        LoadButton                   matlab.ui.control.Button
        AudioCompressionLabel        matlab.ui.control.Label
        UIAxes2                      matlab.ui.control.UIAxes
        UIAxes                       matlab.ui.control.UIAxes
    end


    properties (Access = private)
        orig_filename
        orig_size
        orig_x
        orig_Fs
        orig_time % Description
    end


    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: LoadButton
        function LoadButtonPushed(app, event)
            global filename;
            filename = uigetfile({'*.mp3;*.wav;*.flac', 'Audio files (*.mp3, *.wav, *.flac)'},'Select an Audio file');
            app.FilenameEditField.Value = filename;
            fileinfo = dir(filename);
            size = fileinfo.bytes/1024;
            app.OrignalSizeTextArea.Value = strcat(num2str(size), ' KB');
            [x, Fs] = audioread(filename);
            time = 0:1/Fs:(length(x) - 1)/Fs;
            app.orig_filename = filename;
            app.orig_Fs = Fs;
            app.orig_size = size;
            app.orig_x = x;
            app.orig_time = time;
            plot(app.UIAxes, app.orig_time, app.orig_x);
            cla(app.UIAxes2)
            app.CompressedFilenameEditField.Value = '';
            app.CompressedSizeTextArea.Value = '';
        end

        % Button pushed function: CompressButton
        function CompressButtonPushed(app, event)
            global filename;
            if(~ischar(filename))
                errordlg('No audio file selected!');
            else
                wavelet = 'haar';
                level = 5;
                % frame_size = 2048;
                frame_size = 8192;
                psychoacoustic = 'on';
                wavelet_compression = 'on';
                heavy_compression = 'off';
                compander = 'on';
                quantization = 'on';

                %%%%%%%%%%
                % Encode %
                %%%%%%%%%%

                % Decomposition using N equal frames
                % Phân tích ra N khung bằng nhau
                step = frame_size;
                N = ceil(length(app.orig_x) / step);

                % Computational variables
                % Các biến tính toán
                Cchunks = 0;
                Lchunks = 0;
                Csize = 0;
                PERF0mean = 0;
                PERFL2mean = 0;
                n_avg = 0;
                n_max = 0;
                n_0 = 0;
                n_vector = [];

                for i= 1:1:N
                    if(i == N)
                        frame = app.orig_x([(step * (i - 1) + 1) : length(app.orig_x)]);
                    else
                        frame = app.orig_x([(step * (i - 1) + 1) : step * i]);
                    end

                    % Wavelet decomposition of the frame
                    % Phân tách wavelet của khung
                    [C, L] = wavedec(frame, level, wavelet);

                    % Wavelet compression scheme
                    % Cơ chế nén wavelet
                    if strcmp(wavelet_compression, 'on') == 1
                        [thr, sorh, keepapp] = ddencmp('cmp', 'wv', frame);
                        if strcmp(heavy_compression, 'on') == 1
                            thr = thr * 10 ^ 6;
                        end
                        [XC, CXC, LXC, PERF0, PERFL2] = wdencmp("gbl", C, L, wavelet, level, thr, sorh, keepapp);
                        C = CXC;
                        L = LXC;
                        PERF0mean = PERF0mean + PERF0;
                        PERFL2mean = PERFL2mean + PERFL2;
                    end

                    % Psychoacoustic model
                    %
                    if strcmp(psychoacoustic, 'on') == 1
                        P = 10.*log10((abs(fft(frame, length(frame)))).^2);
                        Ptm = zeros(1, length(P));

                        % Inspect spectrum and find tone maskers
                        % Kiểm tra quang phổ và tìm các mặt nạ âm thanh(??)
                        for k = 1:1:length(P)
                            if ((k <= 1) || (k >= 250))
                                bool = 0;
                            elseif ((P(k)<P(k-1)) || (P(k)<P(k+1)))
                                bool = 0;
                            elseif ((k>2) && (k<63))
                                bool = ((P(k)>(P(k-2)+7)) & (P(k)>(P(k+2)+7)));
                            elseif ((k>=63) && (k<127))
                                bool = ((P(k)>(P(k-2)+7)) & (P(k)>(P(k+2)+7)) & (P(k)>(P(k-3)+7)) & (P(k)>(P(k+3)+7)));
                            elseif ((k>=127) && (k<=256))
                                bool = ((P(k)>(P(k-2)+7)) & (P(k)>(P(k+2)+7)) & (P(k)>(P(k-3)+7)) & (P(k)>(P(k+3)+7)) & (P(k)>(P(k-4)+7)) & (P(k)>(P(k+4)+7)) &(P(k)>(P(k-5)+7)) & (P(k)>(P(k+5)+7)) & (P(k)>(P(k-6)+7)) &(P(k)>(P(k+6)+7)));
                            else
                                bool = 0;
                            end

                            if bool == 1
                                Ptm(k)=10*log10(10.^(0.1.*(P(k - 1)))+10.^(0.1.*(P(k)))+10.^(0.1.*P(k + 1)));
                            end
                        end
                        sum_energy = 0;
                        for k = 1:1:length(Ptm)
                            sum_energy = 10.^(0.1.^(Ptm(k))) + sum_energy;
                        end
                        E = 10*log10(sum_energy/length(Ptm));
                        SNR = max(P) - E;
                        n = ceil(SNR / 6.02);
                        if n <= 3
                            n = 4;
                            n_0 = n_0 + 1;
                        end
                        if n > n_max
                            n_max = n;
                        end
                        n_avg = n + n_avg;
                        n_vector = [n_vector n];
                    end

                    % Compander (compressor)
                    %
                    if strcmp(compander, 'on') == 1
                        Mu = 255;
                        C = compand(C, Mu, max(C), 'mu/compressor');
                    end

                    if strcmp(quantization, 'on') == 1
                        if strcmp(psychoacoustic, 'off') == 0
                            n = 8;
                        end
                        partition = [min(C):((max(C) - min(C))/2^n):max(C)];
                        codebook = [(min(C) - (max(C) - min(C)) / 2 ^ n):((max(C) - min(C))/2^n):max(C)];
                        [index, quant, distor] = quantiz(C, partition, codebook);

                        % Find and correct offset
                        offset = 0;
                        for j=1:1:N
                            if C(j) == 0
                                offset = -quant(j);
                                break;
                            end
                        end
                        quant = quant + offset;
                        C = quant;
                    end

                    % Put together all the chunks
                    % Ghép các khung lại với nhau
                    Cchunks=[Cchunks C];
                    Lchunks=[Lchunks L];
                    Csize=[Csize length(C)];
                    Encoder = round((i/N)*100)  %indicator of progess
                end
                Cchunks = Cchunks(2:length(Cchunks));
                Csize = [Csize(2) Csize(N+1)];
                Lsize = length(L);
                Lchunks = [Lchunks(2:Lsize + 1) Lchunks((N - 1)*Lsize + 1:length(Lchunks))];
                PERF0mean = PERF0mean/N         % indicator
                PERFL2mean = PERFL2mean/N       % indicator
                n_avg = n_avg/N                 % indicator
                n_max                           % indicator
                end_of_encoder = 'done'         % indicator of progress

                %%%%%%%%%%
                % Decode %
                %%%%%%%%%%
                %reconstruction using N equal frames of length step (except the last one)
                xdchunks = 0;
                for i = 1:1:N
                    if i == N
                        Cframe=Cchunks([((Csize(1) * (i - 1)) + 1):Csize(2)+(Csize(1) * (i - 1))]);
                        %Compander (expander)
                        if strcmp(compander, 'on') == 1
                            if max(Cframe) == 0
                            else
                                Cframe = compand(Cframe, Mu, max(Cframe), 'mu/expander');
                            end
                        end
                        xd = waverec(Cframe,Lchunks(Lsize+2:length(Lchunks)),wavelet);
                    else
                        Cframe=Cchunks([((Csize(1)*(i-1))+1):Csize(1)*i]);
                        %Compander (expander)
                        if strcmp(compander, 'on')  == 1
                            if max(Cframe) == 0
                            else
                                Cframe = compand(Cframe, Mu, max(Cframe), 'mu/expander');
                            end
                        end
                        xd = waverec(Cframe,Lchunks(1:Lsize),wavelet);
                    end

                    xdchunks=[xdchunks xd];
                    Decoder = round((i/N)*100)  % indicator of progress
                end
                xdchunks = xdchunks(2:length(xdchunks));
                % distorsion = sum((xdchunks - app.orig_x).^2)/length(x)
                end_of_decoder = 'done'

                % Creating audio file with compressed schemes
                audiowrite(strcat('compressed_', app.orig_filename), xdchunks, app.orig_Fs);
                end_of_writing_file = 'done'    % indicator of progress

                % Show new compressed file properties
                new_filename = strcat('compressed_', app.orig_filename);
                new_fileinfo = dir(new_filename);
                new_size = new_fileinfo.bytes/1024;
                app.CompressedFilenameEditField.Value = new_filename;
                app.CompressedSizeTextArea.Value = strcat(num2str(new_size), ' KB');
                [new_x, new_Fs] = audioread(new_filename);
                new_time = 0:1/new_Fs:(length(new_x) - 1)/new_Fs;
                plot(app.UIAxes2, new_time, new_x);


            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1339 423];
            app.UIFigure.Name = 'MATLAB App';

            % Create UIAxes
            app.UIAxes = uiaxes(app.UIFigure);
            title(app.UIAxes, 'Original ')
            xlabel(app.UIAxes, 'Time(s)')
            zlabel(app.UIAxes, 'Z')
            app.UIAxes.Position = [25 120 547 185];

            % Create UIAxes2
            app.UIAxes2 = uiaxes(app.UIFigure);
            title(app.UIAxes2, 'Compressed')
            xlabel(app.UIAxes2, 'Time(s)')
            zlabel(app.UIAxes2, 'Z')
            app.UIAxes2.Position = [747 120 551 185];

            % Create AudioCompressionLabel
            app.AudioCompressionLabel = uilabel(app.UIFigure);
            app.AudioCompressionLabel.HorizontalAlignment = 'center';
            app.AudioCompressionLabel.FontName = 'Calibri';
            app.AudioCompressionLabel.FontSize = 16;
            app.AudioCompressionLabel.FontWeight = 'bold';
            app.AudioCompressionLabel.Position = [556 381 231 23];
            app.AudioCompressionLabel.Text = 'Audio Compression';

            % Create LoadButton
            app.LoadButton = uibutton(app.UIFigure, 'push');
            app.LoadButton.ButtonPushedFcn = createCallbackFcn(app, @LoadButtonPushed, true);
            app.LoadButton.Position = [264 329 100 22];
            app.LoadButton.Text = 'Load';

            % Create OrignalSizeTextAreaLabel
            app.OrignalSizeTextAreaLabel = uilabel(app.UIFigure);
            app.OrignalSizeTextAreaLabel.HorizontalAlignment = 'right';
            app.OrignalSizeTextAreaLabel.Position = [67 49 71 22];
            app.OrignalSizeTextAreaLabel.Text = 'Orignal Size';

            % Create OrignalSizeTextArea
            app.OrignalSizeTextArea = uitextarea(app.UIFigure);
            app.OrignalSizeTextArea.Editable = 'off';
            app.OrignalSizeTextArea.HorizontalAlignment = 'center';
            app.OrignalSizeTextArea.Position = [406 50 157 20];

            % Create CompressButton
            app.CompressButton = uibutton(app.UIFigure, 'push');
            app.CompressButton.ButtonPushedFcn = createCallbackFcn(app, @CompressButtonPushed, true);
            app.CompressButton.Position = [991 329 100 22];
            app.CompressButton.Text = 'Compress';

            % Create CompressedSizeTextAreaLabel
            app.CompressedSizeTextAreaLabel = uilabel(app.UIFigure);
            app.CompressedSizeTextAreaLabel.HorizontalAlignment = 'center';
            app.CompressedSizeTextAreaLabel.Position = [798 49 100 22];
            app.CompressedSizeTextAreaLabel.Text = 'Compressed Size';

            % Create CompressedSizeTextArea
            app.CompressedSizeTextArea = uitextarea(app.UIFigure);
            app.CompressedSizeTextArea.Editable = 'off';
            app.CompressedSizeTextArea.HorizontalAlignment = 'center';
            app.CompressedSizeTextArea.Position = [1138 50 158 20];

            % Create FilenameEditFieldLabel
            app.FilenameEditFieldLabel = uilabel(app.UIFigure);
            app.FilenameEditFieldLabel.HorizontalAlignment = 'right';
            app.FilenameEditFieldLabel.Position = [66 83 55 22];
            app.FilenameEditFieldLabel.Text = 'Filename';

            % Create FilenameEditField
            app.FilenameEditField = uieditfield(app.UIFigure, 'text');
            app.FilenameEditField.Editable = 'off';
            app.FilenameEditField.HorizontalAlignment = 'right';
            app.FilenameEditField.Position = [406 83 157 20];

            % Create FilenameEditField_2Label
            app.FilenameEditField_2Label = uilabel(app.UIFigure);
            app.FilenameEditField_2Label.HorizontalAlignment = 'right';
            app.FilenameEditField_2Label.Position = [799 84 55 22];
            app.FilenameEditField_2Label.Text = 'Filename';

            % Create CompressedFilenameEditField
            app.CompressedFilenameEditField = uieditfield(app.UIFigure, 'text');
            app.CompressedFilenameEditField.Editable = 'off';
            app.CompressedFilenameEditField.HorizontalAlignment = 'right';
            app.CompressedFilenameEditField.Position = [1138 84 158 20];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = from_the_ground_haar_exported

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.UIFigure)
            else

                % Focus the running singleton app
                figure(runningApp.UIFigure)

                app = runningApp;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end