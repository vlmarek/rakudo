class CompUnit::Repository::FileSystem does CompUnitRepo::Locally does CompUnit::Repository {

    my %extensions =
      Perl6 => <pm6 pm>,
      Perl5 => <pm5 pm>,
      NQP   => <nqp>,
      JVM   => ();

    # global cache of files seen
    my %seen;

    method files($file, :$name, :$auth, :$ver) {
        my $base := $file.IO;
        $base.f
         ?? { files => { $file => $base.path }, ver => Version.new('0') }
         !! ();
    }

    method load(Str:D $file, \GLOBALish is raw = Any, :$line) returns CompUnit:D {
        state Str $precomp-ext = $*VM.precomp-ext;  # should be $?VM probably
        my $dir-sep           := $*SPEC.dir-sep;

        # We have a $file when we hit: require "PATH" or use/require Foo:file<PATH>;
        my $has_precomp = $file.ends-with($precomp-ext);
        my $path = $file.IO.is-absolute
                ?? $file
                !! $!IO.abspath ~ $dir-sep ~ $file;

        if IO::Path.new-from-absolute-path($path).f {
            my $compunit = %seen{$path} = CompUnit.new(
              $path, :$file, :extension(''), :has-source(!$has_precomp), :$has_precomp, :repo(self)
            );
            $compunit.load(GLOBALish, :$line);
            return $compunit;
        }

        return self.next-repo.load($file, :$line) if self.next-repo;
        nqp::die("Could not find $file in:\n" ~ $*REPO.repo-chain.map(*.Str).join("\n").indent(4));
    }

    method candidates(
      $name,
      :$from = 'Perl6',
      :$auth,           # not used here (yet)
      :$ver,            # not used here (yet)
      ) {

        # sorry, cannot handle this one
        return () unless %extensions.EXISTS-KEY($from);

        state Str $precomp-ext = $*VM.precomp-ext;  # should be $?VM probably
        my $dir-sep           := $*SPEC.dir-sep;

        # pick a META6.json if it is there
        if (my $meta = ($!IO.abspath ~ $dir-sep ~ 'META6.json').IO) && $meta.f {
            my $json = from-json $meta.slurp;
            if $json<provides>{$name} -> $file {
                my $has_precomp = $file.ends-with($precomp-ext);
                my $has_source  = !$has_precomp;
                my $path        = $file.IO.is-absolute
                                ?? $file
                                !! $!IO.abspath ~ $dir-sep ~ $file;
                $has_precomp    = ?IO::Path.new-from-absolute-path($path ~ '.' ~ $precomp-ext).f
                    unless $has_precomp;

                return %seen{$path} = CompUnit.new(
                  $path, :$name, :extension(''), :$has_source, :$has_precomp, :repo(self)
                ) if IO::Path.new-from-absolute-path($path).f;
            }
        }
        # deduce path to compilation unit from package name
        else {
            my $base := $!IO.abspath ~ $dir-sep ~ $name.subst(:g, "::", $dir-sep) ~ '.';
            if %seen{$base} -> $found {
                return $found;
            }

            # have extensions to check
            if %extensions{$from} -> @extensions {
                for @extensions -> $extension {
                    my $path = $base ~ $extension;
                    return %seen{$base} = CompUnit.new(
                      $path, :$name, :$extension, :has-source, :repo(self)
                    ) if IO::Path.new-from-absolute-path($path).f;
                    return %seen{$base} = CompUnit.new(
                      $path, :$name, :$extension, :!has-source, :has-precomp, :repo(self)
                    ) if IO::Path.new-from-absolute-path($path ~ '.' ~ $precomp-ext).f;
                }
            }

            # no extensions to check, just check compiled version
            elsif $base ~ $precomp-ext -> $path {
                return %seen{$base} = CompUnit.new(
                  $path, :$name, :extension(''), :!has-source, :has-precomp, :repo(self)
                ) if IO::Path.new-from-absolute-path($path).f;
            }
        }

        # alas
        ();
    }

    method short-id() { 'file' }
}

# vim: ft=perl6 expandtab sw=4