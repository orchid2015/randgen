# Copyright (c) 2012, Oracle and/or its affiliates. All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301
# USA


package TestSimplifiedTest;

use base qw(Test::Unit::TestCase);
use lib 'lib';
use strict;
use Carp;
use Cwd;
use GenTest;
use DBServer::MySQL::MySQLd;
use GenTest::Executor;
use GenTest::Properties;
use GenTest::Constants;
use GenTest::Transform;
use GenTest::Validator::Transformer;
use GenTest::Simplifier::Test;
use GenTest::Simplifier::SQL;

sub new {
    my $self = shift()->SUPER::new(@_);
    # your state for fixture here
    return $self;
}

my $executor;
my $server;
my @pids;

# Setup and start the server
sub set_up {
    my $self=shift;
    
    my $vardir= cwd()."/unit/tmp";
    
    my $portbase = 20 + ($ENV{TEST_PORTBASE}?int($ENV{TEST_PORTBASE}):22120);
    
    $self->assert(defined $ENV{RQG_MYSQL_BASE},"RQG_MYSQL_BASE not defined");
    
    $server = DBServer::MySQL::MySQLd->new(basedir => $ENV{RQG_MYSQL_BASE},
        vardir => $vardir,
        port => $portbase);
    $self->assert_not_null($server);
    
    $self->assert(-f $vardir."/data/mysql/db.MYD","No ".$vardir."/data/mysql/db.MYD");
    
    $server->startServer;
    push @pids,$server->serverpid;
    
    my $dsn = $server->dsn("test");
    $self->assert_not_null($dsn);
    
    $executor = GenTest::Executor->newFromDSN($dsn);
    $self->assert_not_null($executor);
    $executor->init();
    
    $self->assert(-f $vardir."/mysql.pid") if not osWindows();
    $self->assert(-f $vardir."/mysql.err");
    
}

# Stop the server
sub tear_down {
    my $self = shift;
    
    $server->stopServer;
    
    if (osWindows) {
        ## Need to ,kill leftover processes if there are some
        foreach my $p (@pids) {
            Win32::Process::KillProcess($p,-1);
        }
        system("rmdir /s /q unit\\tmp");
    } else {
        ## Need to ,kill leftover processes if there are some
        kill 9 => @pids;
        # system("rm -rf unit/tmp");
    }
}

# Method for calling the required transformer
sub transform {
    my($self,$query,$result,$transformer_name)=@_;
    
    eval ('require GenTest::Transform::'.$transformer_name) or croak $@;
    my $transformer = ('GenTest::Transform::'.$transformer_name)->new();
    $self->assert_not_null($transformer);
    
    my ($transform_outcome, @transformed_queries) = $transformer->transformExecuteValidate($query, $result, $executor);
    $self->assert_not_null($transform_outcome);
    
    return @transformed_queries;
}


# Method for generating testcase for the queries passed.
# Testcase file is also created under unit/ for debug
sub check_testcase {
    my ($self,$query,$transformed_queries)=@_;
    
    my $transform = GenTest::Simplifier::Test->new(
        executors => [ $executor ],
        queries => [ $query , join(';',@$transformed_queries) ]
        );
    $self->assert_not_null($transform);
    
    my $test = $transform->simplify();
    $self->assert_not_null($test);
    
    my $testfile = "unit"."/".time().".test";
    open (TESTFILE , ">$testfile");
    print TESTFILE $test;
    close (TESTFILE);
    
    return $test;
}

# Test Method, which can be extended
# a) Contains the ddl,dml & query required for the test
# b) Contains a list of transformer which is required to test
# c) Contains a list of patterns which are to be checked in the testcase
# Bug 13625626
sub test_create_drop_database_transform_exists {
    my $self = shift;
    
    my $result = $executor->execute("CREATE TABLE `t1` (`col_time_not_null_key` time NOT NULL,`col_time_1` time DEFAULT NULL, `pk` datetime NOT NULL DEFAULT '0000-00-00 00:00:00', `col_time_2_key` time DEFAULT NULL, PRIMARY KEY (`pk`), KEY `col_time_not_null_key` (`col_time_not_null_key`), KEY `col_time_2_key` (`col_time_2_key`)) ENGINE=InnoDB DEFAULT CHARSET=latin1/*!50100 PARTITION BY KEY (pk) PARTITIONS 2 */;");
    
    $self->assert_not_null($result);
    $self->assert_equals($result->status, 0);
    
    my $result = $executor->execute("INSERT INTO `t1` VALUES ('00:20:02','06:16:36','2011-09-09 21:37:45','19:15:37'),('18:00:14','00:20:04','2011-09-09 21:37:46','06:21:03');");
    $self->assert_not_null($result);
    $self->assert_equals($result->status, 0);
    
    my $query = "SELECT `col_time_1` AS c1 FROM `t1` WHERE `col_time_2_key` > SUBTIME( '2006-07-16' , '05:05:02.040778' ) ORDER BY `col_time_2_key` , `col_time_1`";
    
    my $result = $executor->execute($query);
    $self->assert_not_null($result);
    $self->assert_equals($result->status, 0);
    
    # List of tranformers to be used.
    my @transformer_names=qw(ExecuteAsView ExecuteAsWhereSubquery ExecuteAsInsertSelect ExecuteAsTrigger ExecuteAsUpdateDelete);
    
    # List of patterns to be checked.
    my @test_patterns=('CREATE DATABASE IF NOT EXISTS transforms;','DROP DATABASE IF EXISTS TRANSFORMS;');
    
    # Create a transform database for the different transformers. 
    $executor->dbh()->do("CREATE DATABASE IF NOT EXISTS transforms");
    
    foreach my $transformer_name (@transformer_names) {
        my @transformed_queries=$self->transform($query,$result,$transformer_name);
        $self->assert_not_null(@transformed_queries);
        
        my $testcase=$self->check_testcase($query,\@transformed_queries);
        foreach my $test_pattern (@test_patterns) {
            $self->assert_matches(qr/$test_pattern/si,$testcase);
        }
    }
}

# Test Method, which can be extended
# a) Contains the ddl & query required for the test
# b) Contains a list of transformer which is required to test
# c) Contains a list of patterns which are to be checked in the testcase
# Bug 13625626
sub test_create_drop_database_transform_not_exists {
    my $self = shift;
    
    my $result = $executor->execute("CREATE TABLE `t1` (`col_time_not_null_key` time NOT NULL,`col_time_1` time DEFAULT NULL, `pk` datetime NOT NULL DEFAULT '0000-00-00 00:00:00', `col_time_2_key` time DEFAULT NULL, PRIMARY KEY (`pk`), KEY `col_time_not_null_key` (`col_time_not_null_key`), KEY `col_time_2_key` (`col_time_2_key`)) ENGINE=InnoDB DEFAULT CHARSET=latin1/*!50100 PARTITION BY KEY (pk) PARTITIONS 2 */;");
    
    $self->assert_not_null($result);
    $self->assert_equals($result->status, 0);
    
    my $result = $executor->execute("INSERT INTO `t1` VALUES ('00:20:02','06:16:36','2011-09-09 21:37:45','19:15:37'),('18:00:14','00:20:04','2011-09-09 21:37:46','06:21:03');");
    $self->assert_not_null($result);
    $self->assert_equals($result->status, 0);
    
    my $query = "SELECT `col_time_1` AS c1 FROM `t1` WHERE `col_time_2_key` > SUBTIME( '2006-07-16' , '05:05:02.040778' ) ORDER BY `col_time_2_key` , `col_time_1`";
    
    my $result = $executor->execute($query);
    $self->assert_not_null($result);
    $self->assert_equals($result->status, 0);
    
    # List of tranformers to be used.
    my @transformer_names=qw(ExecuteAsSPTwice);
    
    # List of patterns to be checked.
    my @test_patterns=('CREATE DATABASE IF NOT EXISTS transforms;','DROP DATABASE IF NOT EXISTS TRANSFORMS;');
    
    # Create a transform database for the different transformers. 
    $executor->dbh()->do("CREATE DATABASE IF NOT EXISTS transforms");
    
    foreach my $transformer_name (@transformer_names) {
        my @transformed_queries=$self->transform($query,$result,$transformer_name);
        $self->assert_not_null(@transformed_queries);
        
        my $testcase=$self->check_testcase($query,\@transformed_queries);
        foreach my $test_pattern (@test_patterns) {
            $self->assert_does_not_match(qr/$test_pattern/si,$testcase);
        }
    }
}


# Test Method, which can be extended
# a) Contains the ddl,dml & query required for the test
# b) Contains a list of transformer which is required to test
# c) Contains a list of patterns which are to be checked in the testcase
# Bug 13625626
sub test_create_drop_database_literals_exists {
    my $self = shift;
    
    my $result = $executor->execute("CREATE TABLE `t1` (`col_time_not_null_key` time NOT NULL,`col_time_1` time DEFAULT NULL, `pk` datetime NOT NULL DEFAULT '0000-00-00 00:00:00', `col_time_2_key` time DEFAULT NULL, PRIMARY KEY (`pk`), KEY `col_time_not_null_key` (`col_time_not_null_key`), KEY `col_time_2_key` (`col_time_2_key`)) ENGINE=InnoDB DEFAULT CHARSET=latin1/*!50100 PARTITION BY KEY (pk) PARTITIONS 2 */;");

    $self->assert_not_null($result);
    $self->assert_equals($result->status, 0);
    
    my $result = $executor->execute("INSERT INTO `t1` VALUES ('00:20:02','06:16:36','2011-09-09 21:37:45','19:15:37'),('18:00:14','00:20:04','2011-09-09 21:37:46','06:21:03');");
    $self->assert_not_null($result);
    $self->assert_equals($result->status, 0);
    
    my $query = "SELECT `col_time_1` AS c1 FROM `t1` WHERE `col_time_2_key` > SUBTIME( '2006-07-16' , '05:05:02.040778' ) ORDER BY `col_time_2_key` , `col_time_1`";
    
    my $result = $executor->execute($query);
    $self->assert_not_null($result);
    $self->assert_equals($result->status, 0);
    
    # List of tranformers to be used.
    my @transformer_names=qw(ConvertLiteralsToSubqueries);
    
    # List of patterns to be checked.
    my @test_patterns=('DROP DATABASE IF EXISTS literals;');
    
    foreach my $transformer_name (@transformer_names) {
        my @transformed_queries=$self->transform($query,$result,$transformer_name);
        $self->assert_not_null(@transformed_queries);
        
        my $testcase=$self->check_testcase($query,\@transformed_queries);
        foreach my $test_pattern (@test_patterns) {
            $self->assert_matches(qr/$test_pattern/si,$testcase);
        }
    }
}


1;
