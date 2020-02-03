
use v6.d;

class Text::Diff::Base {
    method file-header($a, $b) {
        return "";
    }

    method display-filename($filename-prefix, $filename, $mtime) {
        my $name = q{};
        $name ~= $filename-prefix ~ q{ } with $filename-prefix;
        $name ~= $filename;
        $name ~= qq{\t} ~ $mtime.to-posix[0] with $mtime;

        return $name;
    }

    # range encapsulates the building of, well, ranges.  Turns out there are
    # a few nuances.
    method range ( @ops, $a-or-b, $format ) {
        my $start = @ops[ 0].linenum($a-or-b);
        my $after = @ops[*-1].linenum($a-or-b);

        # The sequence indexes in the lines are from *before* the OPCODE is
        # executed, so we bump the last index up unless the OP indicates
        # it didn't change.
        ++$after unless @ops[*-1].opcode eq ( ($a-or-b eq 'A') ?? "+" !! "-" );

        # convert from 0..n index to 1..(n+1) line number.  The unless modifier
        # handles diffs with no context, where only one file is affected.  In this
        # case $start == $after indicates an empty range, and the $start must
        # not be incremented.
        my $empty-range = $start == $after;
        ++$start unless $empty-range;

        return $start == $after
                ?? $format eq "unified" && $empty-range
                        ?? "%d,0".sprintf($start)
                        !! "%d".sprintf($start)
                !! $format eq "unified"
        ?? "%d,%d".sprintf($start, ($after - $start + 1))
                !! "%d,%d".sprintf($start, $after - 1);
    }

    method op-to-line ( $seq, $op, $a-or-b, $op-prefixes ) {
        my $opcode = $op.opcode;
        return unless defined $op-prefixes{$opcode};

        my $op-sym = $op.changed-line ?? q{!} !! $opcode;
        $op-sym = $op-prefixes{$op-sym};
        return unless $op-sym.defined;

        my $linenum = $op.linenum($a-or-b);
        my @line = ( $op-sym, $seq.lines[$linenum] );
        # FIXME: Trailing \n stripped by lines() so this is impossible to know.
        #        unless $seq.lines[$linenum + 1].defined {
        #           @line[1] ~= "\n\\ No newline at end of file\n";
        #        }

        return @line.join(q{});
    }

    method hunk-header ($a, $b, @ops) {
        return ""
    }

    method hunk ($a, $b, @ops) {
        return ""
    }

    method hunk-footer ($a, $b, @ops) {
        return ""
    }

    method file-footer ($a, $b) {
        return ""
    }
}

class Text::Diff::Crap {}

class Text::Diff::Unified is Text::Diff::Base {
    method file-header($a, $b) {
        return "%s\n%s\n".sprintf(
                self.display-filename('---', $a.name, $a.mtime),
                self.display-filename('+++', $b.name, $b.mtime)
                );
    }

    method hunk-header($a, $b, @ops) {
        return (
                "@@ -",
                        self.range( @ops, 'A', "unified" ),
                        " +",
                        self.range( @ops, 'B', "unified" ),
                        " @@\n",
                ).join(q{});
    }

    method hunk($a, $b, @ops) {
        my $prefixes = { "+" => "+", " " => " ", "-" => "-" };

        return @ops.map( -> $op {
            my $seq = $b;
            my $a-or-b = 'B';
            if ($op.opcode ne q{+}) {
                $seq = $a;
                $a-or-b = 'A';
            }
            self.op-to-line( $seq, $op, $a-or-b, $prefixes ) ~ "\n";
        }).join(q{});
    }
}

class Text::Diff::Context is Text::Diff::Base {
    method file-header($a, $b) {
        return "%s\n%s\n".sprintf(
                self.display-filename('***', $a.name, $a.mtime),
                self.display-filename('---', $b.name, $b.mtime)
                );
    }

    method hunk-header($a, $b, @lines) {
        return "***************\n";
    }

    method hunk($a, $b, @ops) {
        my $a-range = self.range( @ops, 'A', "" );
        my $b-range = self.range( @ops, 'B', "" );

        ## Sigh.  Gotta make sure that differences that aren't adds/deletions
        ## get prefixed with "!", and that the old opcodes are removed.
        my $after;
        loop ( my $start = 0; $start < @ops.elems - 1 ; $start = $after ) {
            ## Scan until next difference
            $after = $start + 1;
            my $opcode = @ops[$start].opcode;
            next if $opcode eq " ";

            my $bang-it;
            while ( $after <= @ops.elems - 1 && @ops[$after].opcode ne " " ) {
                $bang-it ||= @ops[$after].opcode ne $opcode;
                ++$after;
            }

            if ( $bang-it ) {
                for $start..($after-1) -> $i {
                    @ops[$i].changed-line = True;
                }
            }
        }

        my $b-prefixes = { "+" => "+ ",  " " => "  ", "-" => Nil, "!" => "! " };
        my $a-prefixes = { "+" => Nil, " " => "  ", "-" => "- ",  "!" => "! " };

        my $a-parts = @ops.map( -> $op {self.op-to-line( $a, $op, 'A', $a-prefixes )} ).grep({$_.defined}).join("\n");
        $a-parts ~= "\n" if $a-parts.chars > 0;

        my $b-parts = @ops.map( -> $op {self.op-to-line( $b, $op, 'B', $b-prefixes )} ).grep({$_.defined}).join("\n");
        $b-parts ~= "\n" if $b-parts.chars > 0;

        return (
                "*** ", $a-range, " ****\n", $a-parts,
                        "--- ", $b-range, " ----\n", $b-parts,
                ).join(q{});
    }
}
