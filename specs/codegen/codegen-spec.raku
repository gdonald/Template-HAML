use lib 'lib';
use BDD::Behave;
use MONKEY-SEE-NO-EVAL;
use Template::HAML;
use Template::HAML::Codegen;
use Template::HAML::Config;

sub compile-and-call(Str $src, %locals = (), Template::HAML::Config :$config) {
  my $source = HAML.compile-source-to-raku(:$src, :$config);
  my &fn     = EVAL $source;
  &fn(%locals, :$config);
}

sub clone-locals(%h) {
  my %out;
  for %h.kv -> $k, $v {
    %out{$k} = $v ~~ Positional ?? $v.clone !! $v ~~ Associative ?? $v.clone !! $v;
  }
  %out;
}

sub round-trip-check(Str $src, %locals, Template::HAML::Config :$config) {
  my $expected = HAML.render(:$src, :locals(clone-locals(%locals)), :$config);
  my $actual   = compile-and-call($src, clone-locals(%locals), :$config);
  expect($actual).to.eq($expected);
}

describe 'Template::HAML::Codegen', {
  context 'emitted source shape', {
    it 'mentions Renderer, defines an anon sub, and reconstructs Tag nodes', {
      my $src  = "%p hi\n";
      my $code = HAML.compile-source-to-raku(:$src);
      expect($code).to.include('Template::HAML::Renderer');
      expect($code).to.include('sub (');
      expect($code).to.include('Tag.new(');
    }
  }

  context 'tag round-trips', {
    it 'plain inline tag', { round-trip-check "%p hello\n", %(); }
    it 'nested tags', { round-trip-check "%div\n  %p first\n  %p second\n", %(); }
    it 'void element self-closes', { round-trip-check "%br\n", %(); }
    it 'shorthand classes and id', { round-trip-check "%p.x.y#main hi\n", %(); }
    it 'tag with text content', { round-trip-check "%p Plain text content\n", %(); }
    it 'plain text node', { round-trip-check "Plain at top\n", %(); }
  }

  context 'doctype round-trips', {
    it 'html5 doctype', { round-trip-check "!!!\n%html\n  %body\n", %(); }
    it 'XML declaration', { round-trip-check "!!! XML\n", %(); }
  }

  context 'comment round-trips', {
    it 'visible comment', { round-trip-check "/ a comment\n", %(); }
    it 'silent comment', { round-trip-check "-# silent\n", %(); }
    it 'conditional comment block', { round-trip-check "/[if IE]\n  %p hi\n", %(); }
  }

  context 'statement round-trips', {
    it 'expression statement', { round-trip-check "= \$name\n", %(name => 'World'); }
    it 'unescaped expression', { round-trip-check "!= \$raw\n", %(raw => '<b>x</b>'); }
    it 'force-escape statement', { round-trip-check "&= \$x\n", %(x => '<x>'); }
    it 'string interpolation statement', { round-trip-check "== Hello, \#\{\$name\}!\n", %(name => 'World'); }
    it 'tag-output uses local', { round-trip-check "%p= \$x\n", %(x => 1); }
  }

  context 'control-flow round-trips', {
    it 'for loop', {
      round-trip-check Q:to/HAML/, %(items => [1, 2, 3]);
      - for $items -> $i
        %li= $i
      HAML
    }

    it 'if/elsif/else chain', {
      round-trip-check Q:to/HAML/, %(n => 2);
      - if $n == 1
        %p one
      - elsif $n == 2
        %p two
      - else
        %p other
      HAML
    }

    it 'while loop drains array', {
      round-trip-check Q:to/HAML/, %(items => [1, 2, 3].Array);
      - while $items.elems
        %li= $items.shift
      HAML
    }

    it 'given/when statement', {
      round-trip-check Q:to/HAML/, %(label => 2);
      - given $label
        - when 1
          %p one
        - when 2
          %p two
        - default
          %p other
      HAML
    }
  }

  context 'attribute round-trips', {
    it 'static attrs', { round-trip-check Q[%a(href='/' title='Home') home] ~ "\n", %(); }
    it 'dynamic hash attr', { round-trip-check Q[%a{href: "#{$url}"} go] ~ "\n", %(url => '/x'); }
    it 'data hash expansion', { round-trip-check Q[%div{data: {foo: 1, bar: 'baz'}} body] ~ "\n", %(); }

    it 'attribute splat', {
      my %sp = href => '/about', title => 'About';
      round-trip-check Q[%a{|$attrs} link] ~ "\n", %(attrs => %sp);
    }

    it 'splat merges with shorthand', {
      round-trip-check Q[%div.shorthand{|$attrs} body] ~ "\n", %(attrs => { class => 'extra' });
    }

    it 'object reference', {
      my class Account {
        has Int $.id;
        method haml-object-ref(--> Str) { 'account' }
      }
      my $acct = Account.new(:id(7));
      round-trip-check Q[%div[$acct] hi] ~ "\n", %(acct => $acct);
    }

    it 'interpolated class shorthand', {
      round-trip-check Q[%li.item-#{$id} hi] ~ "\n", %(id => 42);
    }
  }

  context 'filter round-trips', {
    it 'plain filter with interpolation', {
      round-trip-check Q:to/HAML/, %(name => 'World');
      :plain
        hello #{$name}
      HAML
    }

    it 'escaped filter', {
      round-trip-check Q:to/HAML/, %();
      :escaped
        <b>x</b>
      HAML
    }
  }

  context 'config round-trips', {
    it 'xhtml self-close in compiled output', {
      my $cfg = Template::HAML::Config.new(:format<xhtml>);
      round-trip-check "%br\n", %(), :config($cfg);
    }
  }

  context 'mixed templates', {
    it 'nested with statements and tags', {
      round-trip-check Q:to/HAML/, %(name => 'world');
      %html
        %body
          %h1
            = "Hello, " ~ $name
          %ul
            - for ^3 -> $i
              %li= $i
      HAML
    }
  }
}
