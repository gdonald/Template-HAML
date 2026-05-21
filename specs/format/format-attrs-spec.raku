use lib 'lib';
use BDD::Behave;
use Template::HAML::Format;

sub fmt(Str:D $src) { format-source($src) }

my $nl = "\n";

describe 'format-source: attributes and shorthand', {
  context 'class/id shorthand', {
    it 'preserves single class shorthand', {
      expect(fmt('%p.lead' ~ $nl)).to.eq('%p.lead' ~ $nl);
    }

    it 'preserves multiple class shorthand', {
      expect(fmt('%p.lead.intro' ~ $nl)).to.eq('%p.lead.intro' ~ $nl);
    }

    it 'preserves id shorthand', {
      expect(fmt('%section#main' ~ $nl)).to.eq('%section#main' ~ $nl);
    }

    it 'drops implicit %div when class shorthand is present', {
      expect(fmt('%div.foo' ~ $nl)).to.eq('.foo' ~ $nl);
    }

    it 'drops implicit %div when id shorthand is present', {
      expect(fmt('%div#bar' ~ $nl)).to.eq('#bar' ~ $nl);
    }

    it 'drops implicit %div with class+id shorthand', {
      expect(fmt('%div.foo.bar#baz' ~ $nl)).to.eq('.foo.bar#baz' ~ $nl);
    }

    it 'reorders shorthand to classes-then-id', {
      expect(fmt('%p#row.item' ~ $nl)).to.eq('%p.item#row' ~ $nl);
    }
  }

  context 'hash attributes', {
    it 'preserves a simple hash attribute with single quotes', {
      expect(fmt(q{%a{href: '/about'}} ~ $nl)).to.eq(q{%a{href: '/about'}} ~ $nl);
    }

    it 'preserves multiple attributes with content', {
      expect(fmt(q{%a{href: '/about', title: 'home'} link} ~ $nl)).to.eq(
        q{%a{href: '/about', title: 'home'} link} ~ $nl
      );
    }

    it 'preserves void tag with attrs without explicit /', {
      expect(fmt(q{%input{type: 'text', name: 'email'}} ~ $nl)).to.eq(
        q{%input{type: 'text', name: 'email'}} ~ $nl
      );
    }

    it 'normalizes HTML-style attrs to hash form', {
      expect(fmt(q{%a(href='/' title='home')} ~ $nl)).to.eq(
        q{%a{href: '/', title: 'home'}} ~ $nl
      );
    }

    it 'normalizes symbol value to quoted string', {
      expect(fmt(q{%a{href: :home}} ~ $nl)).to.eq(q{%a{href: 'home'}} ~ $nl);
    }

    it 'canonicalizes double-quoted simple string to single quotes', {
      expect(fmt(q{%a{href: "/about"}} ~ $nl)).to.eq(q{%a{href: '/about'}} ~ $nl);
    }

    it 'preserves boolean True attribute', {
      expect(fmt(q{%input{disabled: True}} ~ $nl)).to.eq(
        q{%input{disabled: True}} ~ $nl
      );
    }

    it 'preserves boolean False attribute', {
      expect(fmt(q{%input{checked: False}} ~ $nl)).to.eq(
        q{%input{checked: False}} ~ $nl
      );
    }

    it 'preserves array value', {
      expect(fmt(q{%a{class: ['foo', 'bar']}} ~ $nl)).to.eq(
        q{%a{class: ['foo', 'bar']}} ~ $nl
      );
    }

    it 'preserves nested data hash', {
      expect(fmt(q{%a{data: {id: 1, role: 'main'}}} ~ $nl)).to.eq(
        q{%a{data: {id: 1, role: 'main'}}} ~ $nl
      );
    }

    it 'uses rocket form for hyphenated keys', {
      expect(fmt(q{%a{'data-x' => 'y'}} ~ $nl)).to.eq(
        q{%a{'data-x' => 'y'}} ~ $nl
      );
    }
  }

  context 'splats', {
    it 'preserves attribute splat', {
      expect(fmt(q{%a{|$attrs}} ~ $nl)).to.eq(q{%a{|$attrs}} ~ $nl);
    }

    it 'preserves literal + splat order', {
      expect(fmt(q{%a{href: '/wins', |$attrs}} ~ $nl)).to.eq(
        q{%a{href: '/wins', |$attrs}} ~ $nl
      );
    }

    it 'preserves multiple splats in order', {
      expect(fmt(q{%a{|$a, |$b}} ~ $nl)).to.eq(q{%a{|$a, |$b}} ~ $nl);
    }
  }

  context 'object references', {
    it 'preserves single arg object reference', {
      expect(fmt(q{%div[$user]} ~ $nl)).to.eq(q{%div[$user]} ~ $nl);
    }

    it 'preserves object reference with prefix', {
      expect(fmt(q{%div[$user, 'greeting']} ~ $nl)).to.eq(
        q{%div[$user, 'greeting']} ~ $nl
      );
    }

    it 'preserves shorthand + obj-ref + attrs combined', {
      expect(fmt(q{%p.lead#hero[$user]{class: 'active'}} ~ $nl)).to.eq(
        q{%p.lead#hero[$user]{class: 'active'}} ~ $nl
      );
    }
  }

  context 'idempotence', {
    it 'is idempotent on attrs', {
      expect(fmt(q{%a{href: '/'} home} ~ $nl)).to.eq(
        fmt(fmt(q{%a{href: '/'} home} ~ $nl))
      );
    }

    it 'is idempotent on combined shorthand+attrs', {
      expect(fmt(q{%div.foo.bar#baz{x: 1, y: 'two'}} ~ $nl)).to.eq(
        fmt(fmt(q{%div.foo.bar#baz{x: 1, y: 'two'}} ~ $nl))
      );
    }
  }
}
