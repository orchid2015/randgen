perl runall-trials.pl --output="flush_cached_blocks" --trials=5 --grammar=./mdev15256.yy --duration=1200 --threads=1 --seed=1 --engine=Aria --skip-gendata --gendata-advanced --mysqld=--aria-checkpoint-interval=5 --vardir=/dev/shm/vardir_mdev15256 --basedir=$1
