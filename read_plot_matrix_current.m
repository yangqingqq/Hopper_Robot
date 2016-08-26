function data = read_plot_matrix_current(mySerial)

  nsamples = fscanf(mySerial,'%d');       % first get the number of samples being sent
  data = zeros(nsamples,2);               % two values per sample:  ref and actual

  for i=1:nsamples
    data(i,:) = fscanf(mySerial,'%f %d');  % read in data from PIC32; current->float (A) position->int (um)
    data(i,2) = data(i,2)/1000;            % convert um -> mm
    times(i) = (i-1)*0.5;                  % 0.5 ms between samples
  end
  if nsamples > 1						        
    figure
    stairs(times,data(:,1:2));            % plot the reference and actual
  else
    fprintf('Only 1 sample received\n')
    disp(data);
  end
  % compute the average error
  %score = mean(abs(data(:,1)-data(:,2)));
  %max_current = max(data(:,3))/100;
  %max_force = max(data(:,3))/100*12.5;
  max_depth = max(data(:,2));
  
  fprintf('Max depth: %.2f\n',max_depth)
  title(sprintf('Max depth: %.2f mm',max_depth))
  ylabel('Position (mm)')
  xlabel('Time (ms)')
  legend('current','position')
  
end
