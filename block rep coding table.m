maybe add column for  block, column for rep



pre-warmup: -9, -9

warmup - starts with first cue, ends with some amount of time after last cue or upon seeing first sequence
-3   throughout,  use rep to indicate which digit, have it just start with and end with each cue, with -9 between digits

tutorial - starts with seeing first sequence, ends with first seeing baseline cue
-2 throughout,   rep is -1 when seeing sequence, is 1 or 2 otherwise

baseline - starts with cue onset, ends with training start
-1 throughout, cue_rep is 1

breaks: -8, -9 ///// corresponding block, rep -8

within blocks

block starts with first low dip: corresponding block, rep = -9

seeing sequence: corresponding block, rep = -1
doing verification: corresponding block, rep = -2
break: rep = -8
bw cues: rep = -7
everything else: rep = -9


each block ends with break cue onset /// or maybe with end of break


cue_rep per block = [-9, -9, -1, -2, -1, -9, -9, -7, 1, -7, 2, etc., -8,-8]

overall blocks = [-9, -3, -2, -1, 1, 2, etc., -9]


cues: label these as reps

time before and after cues
corresponding block,  rep = -7

everything else
corresponding block, rep = -9

going to determine hitmiss based on teensy data, it should be fastish if I only consider keys typed during cue. eventually will have a key_onset vector that merges all keys

maybe also import the key switch order/correctness from processed matlab data unless i feel like reparsing based on teensy


or repetition can be x ms after end of the last keypress of prior rep to end of the last keypress for current rep

also want to import jitter list?

maybe just worry about rep later?v