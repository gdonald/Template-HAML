use lib 'lib', 'specs/lib';
use BDD::Behave;
use CodegenHelpers;
use Template::HAML;
use Template::HAML::Config;
use Template::HAML::DirectCodegen;

class Account {
  has Int $.id;
  method haml-object-ref(--> Str) { 'account' }
}

my class User {
  has Int $.id;
}

describe 'direct-emit attributes', {
  context 'emitted code structure', {
    it 'dynamic-attr tag triggers runtime Tag construction, helpers, and state caching', {
      my $tree = HAML.parse-source(:src(Q[%a{|$attrs} go] ~ "\n"));
      my $code = DirectCodegen.new.emit-direct($tree);
      expect($code).to.include('Tag.new(');
      expect($code).to.include('render-direct-tag-open(');
      expect($code).to.include('state $_haml_tag_');
    }

    it 'static-attr tag stays on the fast inline path', {
      my $tree = HAML.parse-source(:src("%p hi\n"));
      my $code = DirectCodegen.new.emit-direct($tree);
      expect($code).to.not.include('Tag.new(');
    }
  }

  context 'interpolated attribute values', {
    it 'InterpString in html-attr value', {
      round-trip-check Q[%a(href="hello #{$x}") hi] ~ "\n", %(x => 'world');
    }

    it 'InterpString in hash-attr value', {
      round-trip-check Q[%a{href: "/u/#{$user}"} go] ~ "\n", %(user => 'alice');
    }

    it 'interpolated class shorthand', {
      round-trip-check Q[%li.item-#{$id} hi] ~ "\n", %(id => 42);
    }

    it 'interpolated id shorthand', {
      round-trip-check Q[%li#row-#{$n} hi] ~ "\n", %(n => 7);
    }

    it 'combined interpolated class + id', {
      round-trip-check Q[%li.item-#{$id}#row-#{$n} hi] ~ "\n", %(id => 1, n => 2);
    }
  }

  context 'attribute splats', {
    it 'plain attribute splat', {
      round-trip-check Q[%a{|$attrs} link] ~ "\n",
        %(attrs => { href => '/about', title => 'About' });
    }

    it 'splat merges with shorthand class', {
      round-trip-check Q[%div.shorthand{|$attrs} body] ~ "\n",
        %(attrs => { class => 'extra' });
    }

    it 'splat concatenates with shorthand id', {
      round-trip-check Q[%div#main{|$attrs} body] ~ "\n",
        %(attrs => { id => 'sub' });
    }

    it 'multiple splats accumulate classes', {
      round-trip-check Q[%a{|$a, |$b} link] ~ "\n",
        %(a => { href => '/x', class => 'a' },
          b => { class => 'b', title => 'T' });
    }
  }

  context 'object references', {
    it 'object reference computes class and id', {
      my $a = Account.new(:id(7));
      round-trip-check Q[%div[$acct] hi] ~ "\n", %(acct => $a);
    }

    it 'object reference with prefix', {
      my $u = User.new(:id(3));
      round-trip-check Q[%div[$user, 'admin'] hi] ~ "\n", %(user => $u);
    }
  }

  context 'dynamic attrs in templates', {
    it 'dynamic attrs inside a for loop', {
      my $src = qq[- for \$items -> \$item\n  %a\{href: "\#\{\$item<href>\}"\}= \$item<name>\n];
      round-trip-check $src,
        %(items => [{name => 'A', href => '/a'}, {name => 'B', href => '/b'}]);
    }

    it 'static attrs + interpolated attrs on same tag', {
      round-trip-check Q[%a.btn(href="/x" title="hi #{$who}") click] ~ "\n", %(who => 'me');
    }

    it 'void tag with interpolated attr value', {
      round-trip-check Q[%input(type='checkbox' value="#{$v}")] ~ "\n", %(v => 'on');
    }

    it 'xhtml void splat self-close', {
      my $cfg    = Template::HAML::Config.new(:format<xhtml>);
      my %locals = attrs => { class => 'spacer' };
      round-trip-check Q[%br{|$attrs}] ~ "\n", %locals, :config($cfg);
    }

    it 'comprehensive dynamic-attr template', {
      my $src = qq[%ul\n  - for \$items -> \$i\n    %li\{class: "\#\{\$i<cls>\}"\}= \$i<n>\n];
      round-trip-check $src,
        %(items => [{cls => 'one', n => 1}, {cls => 'two', n => 2}]);
    }
  }
}
