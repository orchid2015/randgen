our $grammars;
require 'conf/mariadb/include/combo.grammars';

# XA removed due to the amount of bugs
#    --redefine=conf/mariadb/xa.yy

$combinations = [ $grammars,
  [
  '
    --no-mask
    --queries=100M
    --duration=400
    --threads=6
    --seed=time
    --views
    --vcols
    --reporters=Backtrace,ErrorLog,Deadlock
    --validators=TransformerNoComparator
    --transformers=ExecuteAsCTE,ExecuteAsDeleteReturning,ExecuteAsExcept,ExecuteAsExecuteImmediate,ExecuteAsInsertSelect,ExecuteAsIntersect,ExecuteAsUnion,ExecuteAsUpdateDelete,ExecuteAsView,ExecuteAsPreparedTwice,ExecuteAsSPTwice
    --redefine=conf/mariadb/general-workarounds.yy
    --redefine=conf/mariadb/alter_table.yy
    --redefine=conf/mariadb/bulk_insert.yy
    --redefine=conf/mariadb/event.yy
    --redefine=conf/mariadb/instant_add.yy
    --redefine=conf/mariadb/sequences.yy
    --redefine=conf/mariadb/sp.yy
    --redefine=conf/mariadb/versioning.yy
    --mysqld=--log_output=FILE
    --mysqld=--log-bin
    --mysqld=--log_bin_trust_function_creators=1
    --mysqld=--loose-max-statement-time=30
    --mysqld=--loose-debug_assert_on_not_freed_memory=0
    --mysqld=--lock-wait-timeout=10
    --mysqld=--innodb-lock-wait-timeout=5
  '], 
  [
    '--engine=InnoDB --mysqld=--innodb-buffer-pool-size=2G',
    '--engine=MyISAM --mysqld=--default-storage-engine=MyISAM',
    '--engine=Aria --mysqld=--default-storage-engine=Aria',
    '--engine=RocksDB --mysqld=--default-storage-engine=RocksDB --mysqld=--plugin-load-add=ha_rocksdb --mysqld=--binlog-format=ROW',
  ]
];
