use lib 'lib';
use BDD::Behave;
use MONKEY-SEE-NO-EVAL;
use Template::HAML;
use Template::HAML::Config;
use Template::HAML::Context;
use Template::HAML::Eval;
use Template::HAML::HelpersRole;
use Template::HAML::ViewContext;

class MyView does Template::HAML::HelpersRole {
  has Str $.title = 'Hello';
  method greeting { 'world' }
  method user-count { 42 }
  method site-name { 'MySite' }
  method is-admin  { True }
  method shout($s) { $s.uc }
}

describe 'HAML render context', {
  context 'bare ident lookup', {
    it 'locals win over context', {
      my $src = q:to/HAML/;
      %h1
        = title
      HAML

      my $out = HAML.render(
        :src($src),
        :context(MyView.new(:title('Default'))),
        :locals(%(title => 'FromLocal')),
      );
      expect($out).to.match(/'<h1>'\n? \s* 'FromLocal'/);
    }

    it 'falls through to context method', {
      my $src = q:to/HAML/;
      %p
        = greeting
      HAML

      my $out = HAML.render(:src($src), :context(MyView.new));
      expect($out).to.match(/'<p>'\n? \s* 'world'/);
    }

    it 'resolves hyphenated method on context', {
      my $src = q:to/HAML/;
      %span
        = user-count
      HAML

      my $out = HAML.render(:src($src), :context(MyView.new));
      expect($out).to.match(/'<span>'\n? \s* '42'/);
    }

    it 'resolves in if condition', {
      my $src = q:to/HAML/;
      - if is-admin
        %p admin
      - else
        %p user
      HAML

      my $out = HAML.render(:src($src), :context(MyView.new));
      expect($out).to.match(/'<p>admin</p>'/);
    }

    it 'sigil-style locals also work', {
      my $src = q:to/HAML/;
      %p
        = $name
      HAML

      my $out = HAML.render(:src($src), :locals(%(name => 'sigil-form')));
      expect($out).to.match(/'sigil-form'/);
    }

    it 'unknown bare ident with context falls through to eval (fail-loud)', {
      my $src = q:to/HAML/;
      %p
        = unknown-name-xyz
      HAML

      expect({ HAML.render(:src($src), :context(MyView.new)) }).to.raise-error;
    }
  }

  context 'default ViewContext', {
    it 'resolves built-in helpers without explicit context', {
      my $src = q:to/HAML/;
      %div
        != surround('[', ']', { 'inner' })
      HAML

      my $out = HAML.render(:src($src));
      expect($out).to.match(/'[inner]'/);
    }

    it 'exposes built-in helpers as methods', {
      my $vc = Template::HAML::ViewContext.new;
      expect($vc.^can('surround')).to.be-truthy;
      expect($vc.^can('html-safe')).to.be-truthy;
      expect($vc.^can('escape-once')).to.be-truthy;
      expect($vc.^can('list-of')).to.be-truthy;
      expect($vc.^can('find-and-preserve')).to.be-truthy;
    }
  }

  context 'instance + :context', {
    it 'instance render accepts :context', {
      my $haml = HAML.new;
      my $src  = q:to/HAML/;
      %p
        = greeting
      HAML

      my $out = $haml.render(:src($src), :context(MyView.new));
      expect($out).to.match(/'world'/);
    }

    it 'render-cached accepts :context', {
      my $haml = HAML.new(
        :cache(False),
        :compiled-cache-dir($*TMPDIR.add('haml-ctx-' ~ time).IO),
      );
      my $src = q:to/HAML/;
      %p
        = site-name
      HAML

      my $out = $haml.render-cached(:src($src), :context(MyView.new));
      expect($out).to.match(/'MySite'/);
      $haml.clear-compiled-cache;
    }
  }

  context 'extension patterns', {
    it 'role composition (does HelpersRole)', {
      my $vc = MyView.new(:title('T'));
      expect($vc.shout('hi')).to.be('HI');
      expect($vc.surround('(', ')', { 'x' })).to.be('(x)');
    }

    it 'subclassing ViewContext (is ViewContext)', {
      my class SubView is Template::HAML::ViewContext {
        has Str $.page-title = 'Home';
        method site-name { 'MySite' }
      }

      my $vc = SubView.new(:page-title('About'));
      expect($vc.site-name).to.be('MySite');
      expect($vc.page-title).to.be('About');
      expect($vc.surround('<', '>', { 'x' })).to.be('<x>');

      my $out = HAML.render(
        :src("%p\n  = site-name\n"),
        :context(SubView.new),
      );
      expect($out).to.match(/'MySite'/);
    }

    it 'mixing additional roles alongside HelpersRole', {
      my role Greeter {
        method hello { 'hi-from-role' }
      }
      my role Footer {
        method footer-text { 'footer-from-role' }
      }
      my class MultiView does Template::HAML::HelpersRole does Greeter does Footer {
      }

      my $vc = MultiView.new;
      expect($vc.hello).to.be('hi-from-role');
      expect($vc.footer-text).to.be('footer-from-role');
      expect($vc.surround('[', ']', { 'y' })).to.be('[y]');

      my $out = HAML.render(
        :src("%p\n  = hello\n%span\n  = footer-text\n"),
        :context(MultiView.new),
      );
      expect($out).to.match(/'hi-from-role'/);
      expect($out).to.match(/'footer-from-role'/);
    }
  }

  context 'codegen round-trip', {
    it 'preserves bare-ident lookup through compiled template', {
      my $src = q:to/HAML/;
      %p
        = greeting
      HAML

      my $code = HAML.compile-source-to-raku(:$src);
      my &fn   = EVAL $code;

      my $ctx = Template::HAML::Context.new(:user-context(MyView.new));
      my $out = fn(%(), :ctx($ctx));
      expect($out).to.match(/'world'/);
    }
  }

  context 'context methods with arguments', {
    it 'calls a context method bare with an argument', {
      my $out = HAML.render(:src("%p\n  = shout('hi')\n"), :context(MyView.new));
      expect($out).to.match(/'HI'/);
    }

    it 'passes a local as an argument to a bare helper call', {
      my $out = HAML.render(
        :src("%p\n  = shout(\$name)\n"),
        :context(MyView.new),
        :locals(%(name => 'yo')),
      );
      expect($out).to.match(/'YO'/);
    }

    it 'binds a hyphenated helper name for a bare call with arguments', {
      my class HyphenView does Template::HAML::HelpersRole {
        method wrap-it($s) { "[$s]" }
      }

      my $out = HAML.render(:src("%p\n  = wrap-it('x')\n"), :context(HyphenView.new));
      expect($out).to.match(/'[x]'/);
    }

    it 'resolves arg helpers through the interpreted renderer too', {
      my $out = HAML.render(
        :src("%p\n  = shout('hi')\n"),
        :context(MyView.new),
        :config(Template::HAML::Config.new(:emit('ast'))),
      );
      expect($out).to.match(/'HI'/);
    }
  }

  context 'overriding a built-in helper', {
    my class OverrideView does Template::HAML::HelpersRole {
      method surround($pre, $post, &block) { 'OVERRIDDEN' }
    }

    let(:out, {
      HAML.render(
        :src("%div\n  != surround('[', ']', \{ 'inner' })\n"),
        :context(OverrideView.new),
      )
    });

    it 'uses the context method of the same name', {
      expect(out).to.match(/'OVERRIDDEN'/);
    }

    it 'does not fall back to the built-in helper', {
      expect(out).to.not.match(/'[inner]'/);
    }
  }

  context 'declaring helpers explicitly with haml-helper-names', {
    it 'resolves a dynamic helper introspection cannot see', {
      my class DynamicView does Template::HAML::HelpersRole {
        method haml-helper-names { <ping> }
        method FALLBACK($name, |args) {
          $name eq 'ping' ?? 'pong' !! die "no method $name";
        }
      }

      my $out = HAML.render(:src("%p\n  = ping\n"), :context(DynamicView.new));
      expect($out).to.match(/'pong'/);
    }
  }

  context 'context-helper-names', {
    it 'returns nothing without a user', {
      expect(context-helper-names(Nil)).to.eq([]);
    }

    it 'trusts an explicit haml-helper-names list, filtered and sorted', {
      my class ExplicitView {
        method haml-helper-names { <zebra apple apple Bad 9bad ok-name> }
      }

      expect(context-helper-names(ExplicitView.new)).to.eq([<apple ok-name zebra>]);
    }

    it 'lists methods a context adds beyond the Any surface', {
      my class PlainView {
        method greet { 'hi' }
        method wave  { 'bye' }
      }

      expect(context-helper-names(PlainView.new)).to.eq([<greet wave>]);
    }
  }
}
