
use v6.d;

unit module Text::Diff;

use Text::Diff::Output;
use Text::Diff::Table;

use Algorithm::Diff :traverse_sequences;

subset OutputStyle is export of Str where (so $_ eq <Unified Context Table>.any);

class DiffLines {
    has Int $.offset;
    has Str @.lines;
    has Str $.name is required;
    has Instant $.mtime;

    multi submethod BUILD(Array :@!lines, :$!offset = 0, :$!name, :$!mtime) { }

    multi submethod BUILD(Str :$lines, :$!offset = 1, :$!name, :$!mtime) {
        @!lines = $lines.lines;
    }

    multi submethod BUILD(IO::Handle :$lines, :$!offset = 1, :$!name, :$!mtime) {
        @!lines = $lines.slurp.lines
    }
}

class Op {
    has Int $.a-linenum is required;
    has Int $.b-linenum is required;
    has Str $.opcode;

    # Opcode is a + - combination. This is sometimes represented specially
    # via a ! but not always.
    has Bool $.changed-line is rw = False;

    method linenum($a-or-b) {
        return $a-or-b eq 'A' ?? $.a-linenum !! $.b-linenum;
    }
}

sub diff($a-text, $b-text, Int :$offset-a = 0, Int :$offset-b = 0, Str :$filename-a = 'A', Str :$filename-b = 'B',
        Instant :$mtime-a, Instant :$mtime-b,
        OutputStyle :$output-style = 'Unified', Int :$context-lines = 3, *%style-options --> Str) is export
{
    my $a = DiffLines.new(lines => $a-text, offset => $offset-a, name => $filename-a, mtime => $mtime-a);
    my $b = DiffLines.new(lines => $b-text, offset => $offset-b, name => $filename-b, mtime => $mtime-b);

    my $style-module = 'Text::Diff::%s'.sprintf($output-style);
    my $formatter = ::($style-module).new(:$offset-a, :$offset-b, |%style-options);

    # State vars
    my $diffs = 0;
    my @ops;       # ops (" ", +, -) in this hunk
    my $hunks = 0; # Number of hunks

    # We keep 2*context-lines so that if a diff occurs
    # at 2*context-lines we continue to grow the hunk instead
    my $ctx   = 0;

    my $output = q{};

    my $emit-ops = sub (*@args) {
        $output ~= $formatter.file-header( $a, $b ) unless $hunks++;

        # Number of " " (context-lines) ops pushed after last diff.
        $output ~= $formatter.hunk-header( $a, $b, @args );
        $output ~= $formatter.hunk( $a, $b, @args );
        $output ~= $formatter.hunk-footer( $a, $b, @args );
    };
    # of emitting diffs and context as we go. We
    # need to know the total length of both of the two
    # subsequences so the line count can be printed in the
    # header.
    my $dis-a = sub (*@args) {
        my $op = Op.new(a-linenum => @args[0], b-linenum => @args[1], opcode => q{-});
        @ops.push($op);
        $diffs += 1;
        $ctx = 0;
    };
    my $dis-b = sub (*@args) {
        my $op = Op.new(a-linenum => @args[0], b-linenum => @args[1], opcode => q{+});
        @ops.push($op);
        $diffs += 1;
        $ctx = 0;
    };
    traverse_sequences(
            $a.lines, $b.lines,
            MATCH => sub (*@args) {
                my $op = Op.new(a-linenum => @args[0], b-linenum => @args[1], opcode => q{ });
                @ops.push($op);

                if ( $diffs && ++$ctx > $context-lines * 2 ) {
                    $emit-ops(@ops.splice(0, @ops.elems - 1 - $context-lines));
                    $ctx = $diffs = 0;
                }

                # throw away context lines that aren't needed any more
                if ! $diffs && @ops.elems > $context-lines {
                    shift @ops;
                }
            },
            DISCARD_A => $dis-a,
            DISCARD_B => $dis-b,
            );

    # Finish off the context for the diff
    if $diffs > 0 {
        $emit-ops( @ops );
    }

    $output ~= $formatter.file-footer( $a, $b ) if $hunks > 0;

    return $output;
}
