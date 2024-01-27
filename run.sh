#!/bin/bash

#------------------ IMPORTANT -----------------------
# in infer_cli.py match these values:
# index_rate=float(0) #search feature ratio
# filter_radius=float(0) #median filter
# rms_mix_rate=float(0) #search feature
#----------------------------------------------------


# Set the maximum file size for each chunk (in MB)
MAX_SIZE_MB=10

# Convert MB to bytes (1 MB = 1048576 bytes)
max_size_bytes=$((MAX_SIZE_MB * 1048576))

# Get the size of the input file in bytes
file_size_bytes=$(du -b input.mp3 | cut -f1)

# Calculate the duration of the input file in seconds
total_duration=$(ffprobe -i input.mp3 -show_entries format=duration -v quiet -of csv="p=0")

# Calculate the number of chunks needed (rounding up)
num_chunks=$(( (file_size_bytes + max_size_bytes - 1) / max_size_bytes ))

# Calculate duration per chunk
chunk_duration=$(bc <<< "scale=2; $total_duration / $num_chunks")

# Array to hold the filenames of the chunks
declare -a chunk_files

for (( i=0; i<num_chunks; i++ )); do
    start_time=$(bc <<< "scale=2; $chunk_duration * $i")
    output_file="output_$i.mp3"
    ffmpeg -i input.mp3 -ss "$start_time" -t "$chunk_duration" -acodec copy "$output_file"
    chunk_files+=("$output_file")
done
echo "Splitting complete. Generated $num_chunks chunks.\n"

echo "Starting inference..."
chunk_index=0
cd ..
for file in "${chunk_files[@]}"; do
    echo "Process input file $file"
    python infer_cli.py 0 run/$file run/output_$chunk_index.wav run/model/edward.pth run/model/edward.index cuda:0 rmvpe
    ((chunk_index++))
done

echo ""
# Combine all wav files into a single mp3 file
echo "Combining all wav files into a single mp3 file..."
cd run
output_combined="combined_output.mp3"
ffmpeg -f concat -safe 0 -i <(for f in output_*.wav; do echo "file '$PWD/$f'"; done) -c:a libmp3lame -q:a 0 "$output_combined"
echo "Combining complete. File saved as $output_combined"

echo "Completed"