use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Config;

sub round-trip-it(Str $src, %locals, Str $desc) {
  my $expected = HAML.render(:$src, :%locals);
  my $cfg      = Template::HAML::Config.new(:emit<direct>);
  my $actual   = HAML.render(:$src, :%locals, :config($cfg));
  expect($actual).to.eq($expected);
}

describe 'Template::HAML::Config emit', {
  context 'defaults', {
    it 'has the expected default emit value', {
      my $expected = (%*ENV<HAML_DEFAULT_EMIT> // '') eq 'ast' ?? 'ast' !! 'direct';
      my $cfg = Template::HAML::Config.new;
      expect($cfg.emit).to.be($expected);
    }

    it 'allows emit to be set to direct', {
      my $cfg = Template::HAML::Config.new(:emit<direct>);
      expect($cfg.emit).to.be('direct');
    }

    it 'rejects invalid emit values', {
      expect({ Template::HAML::Config.new(:emit<wrong>) }).to.raise-error;
    }
  }

  context 'clone-with', {
    it 'carries emit forward by default', {
      my $cfg = Template::HAML::Config.new(:emit<direct>);
      my $c2 = $cfg.clone-with;
      expect($c2.emit).to.be('direct');
    }

    it 'allows clone-with to override emit', {
      my $cfg = Template::HAML::Config.new(:emit<direct>);
      my $c2 = $cfg.clone-with(:emit<ast>);
      expect($c2.emit).to.be('ast');
    }
  }

  context ':emit<direct> parity with default', {
    it 'renders a simple tag identically', {
      round-trip-it("%p hello\n", %(), 'simple tag');
    }

    it 'renders inline expressions identically', {
      round-trip-it("= \$name\n", %(name => 'World'), 'inline expression');
    }

    it 'renders for loops identically', {
      round-trip-it("- for ^3 -> \$i\n  %li= \$i\n", %(), 'for loop');
    }

    it 'renders filters identically', {
      round-trip-it(":plain\n  hi #\{\$name\}\n", %(name => 'X'), 'filter');
    }

    it 'renders splat attrs identically', {
      round-trip-it(Q[%a{|$attrs} go] ~ "\n",
                    %(attrs => { href => '/x', title => 'X' }),
                    'splat attrs');
    }
  }

  context 'render :file with :emit<direct>', {
    it 'works from a search path', {
      my $tmp = $*TMPDIR.add('haml-emit-test-' ~ $*PID);
      mkdir $tmp unless $tmp.e;
      LEAVE { $tmp.dir».unlink; rmdir $tmp if $tmp.e }

      my $tpl = $tmp.add('hello.haml');
      $tpl.spurt("%h1 Hello, \#\{\$name\}!\n");

      my $haml = HAML.new(:search-paths($tmp.absolute));
      my $cfg  = Template::HAML::Config.new(:emit<direct>);
      my $out  = $haml.render(:file<hello>, :locals(name => 'World'), :config($cfg));
      expect($out.chomp).to.be('<h1>Hello, World!</h1>');
    }
  }

  context 'compile-to-cache with :emit<direct>', {
    it 'writes a cache module and renders correctly', {
      my $tmp = $*TMPDIR.add('haml-emit-cache-' ~ $*PID);
      mkdir $tmp unless $tmp.e;
      LEAVE {
        my sub rm-rec($d) {
          return unless $d.e;
          if $d.d {
            rm-rec($_) for $d.dir;
            rmdir $d;
          } else {
            $d.unlink;
          }
        }
        rm-rec($tmp);
      }

      my $haml = HAML.new(:compiled-cache-dir($tmp));
      my $cfg  = Template::HAML::Config.new(:emit<direct>);
      my $src  = "%p Hello, \#\{\$name\}!\n";
      my $path = $haml.compile-to-cache(:$src, :config($cfg));
      expect($path.e).to.be-truthy;
      my $contents = $path.slurp;
      expect($contents).to.include('our sub haml-render');
      expect($contents).to.include('sub _haml_body');

      my $out = $haml.render-cached(:$src, :locals(name => 'World'), :config($cfg));
      expect($out.chomp).to.be('<p>Hello, World!</p>');
    }
  }

  context 'cache keys', {
    it 'are distinct between ast and direct emit', {
      my $tmp = $*TMPDIR.add('haml-emit-keys-' ~ $*PID);
      mkdir $tmp unless $tmp.e;
      LEAVE {
        my sub rm-rec($d) {
          return unless $d.e;
          if $d.d {
            rm-rec($_) for $d.dir;
            rmdir $d;
          } else {
            $d.unlink;
          }
        }
        rm-rec($tmp);
      }

      my $haml = HAML.new(:compiled-cache-dir($tmp));
      my $src  = "%p hi\n";
      my $ast  = $haml.compiled-cache-key(:$src, :config(Template::HAML::Config.new(:emit<ast>)));
      my $dir  = $haml.compiled-cache-key(:$src, :config(Template::HAML::Config.new(:emit<direct>)));
      expect($ast).to.not.be($dir);
    }
  }
}
