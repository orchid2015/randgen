package GenTest::XML::Test;

require Exporter;
@ISA = qw(GenTest);

use strict;
use GenTest;

#
# Those names are taken from Vemundo's specification for a 
# test result XML report. Not all of them will be used
#

use constant TEST_ID                => 0;
use constant TEST_NAME              => 1;
use constant TEST_ENVIRONMENT_ID    => 2;
use constant TEST_STARTTIME         => 3;
use constant TEST_ENDTIME           => 4;
use constant TEST_LOGDIR            => 5;
use constant TEST_RESULT            => 6;
use constant TEST_DESCRIPTION       => 7;
use constant TEST_ATTRIBUTES        => 8;   
use constant TEST_INCIDENTS         => 9;

1;

sub new {
    my $class = shift;

    my $test = $class->SUPER::new({
        id              => TEST_ID,
        name            => TEST_NAME,
        environment_id  => TEST_ENVIRONMENT_ID,
        starttime       => TEST_STARTTIME,
        endtime         => TEST_ENDTIME,
        logdir          => TEST_LOGDIR,
        result          => TEST_RESULT,
        description     => TEST_DESCRIPTION,
        attributes      => TEST_ATTRIBUTES,
        incidents       => TEST_INCIDENTS
    }, @_);

    $test->[TEST_STARTTIME] = xml_timestamp() if not defined $test->[TEST_STARTTIME];
    $test->[TEST_ENVIRONMENT_ID] = 0 if not defined $test->[TEST_ENVIRONMENT_ID];

    return $test;
}

sub end {
    my ($test, $result) = @_;
    $test->[TEST_ENDTIME] = xml_timestamp();
    $test->[TEST_RESULT] = $result;
}

sub xml {
    require XML::Writer;

    my $test = shift;

    $test->end() if not defined $test->[TEST_ENDTIME];

    my $test_xml;
    my $writer = XML::Writer->new(
        OUTPUT      => \$test_xml,
        UNSAFE      => 1
    );

    $writer->startTag('test', id => $test->[TEST_ID]);

    $writer->dataElement('name',            $test->[TEST_NAME]);
    $writer->dataElement('environment_id',  $test->[TEST_ENVIRONMENT_ID]);
    $writer->dataElement('starttime',       $test->[TEST_STARTTIME]);
    $writer->dataElement('endtime',         $test->[TEST_ENDTIME]);
    $writer->dataElement('logdir',          $test->[TEST_LOGDIR]);
    $writer->dataElement('result',          $test->[TEST_RESULT]);
    $writer->dataElement('description',     $test->[TEST_DESCRIPTION]);

    if (defined $test->[TEST_ATTRIBUTES]) {
        $writer->startTag('attributes');
        while (my ($name, $value) = each %{$test->[TEST_ATTRIBUTES]}) {
            $writer->startTag('attribute');
            $writer->dataElement('name',    $name);
            $writer->dataElement('value',    $value);
            $writer->endTag('attribute');
            #$writer->emptyTag('attribute', 'name' => $name, 'value' => $value);
        }
        $writer->endTag('attributes');
    }

    if (defined $test->[TEST_INCIDENTS]) {
        $writer->startTag('incidents');
        foreach my $incident (@{$test->[TEST_INCIDENTS]}) {
            $writer->raw($incident->xml());
        }
        $writer->endTag('incidents');
    }

    # TODO: <metrics> (name, value, unit, attributes, timestamp)

    $writer->endTag('test');

    $writer->end();

    return $test_xml;
}

sub setId {
    $_[0]->[TEST_ID] = $_[1];
}

sub addIncident {
    my ($test, $incident) = @_;
    $test->[TEST_INCIDENTS] = [] if not defined $test->[TEST_INCIDENTS];
    push @{$test->[TEST_INCIDENTS]}, $incident;
}

1;
