use lib 'lib', 'specs/lib';
use BDD::Behave;
use SpecHelpers;
use Template::HAML;
use Template::HAML::HelpersRole;

class StringSiteContext does Template::HAML::HelpersRole {
  has $.name;
  method site-name { $!name }
}

class StringGreetContext does Template::HAML::HelpersRole {
  has $.who;
  method greeting { "Hello, $!who" }
}

describe 'render-cached resolves context helpers from a string source', {
  context 'a helper referenced by the cached template', {
    let(:haml, { HAML.new(:compiled-cache-dir(fresh-dir())) });

    let(:out, {
      haml.render-cached(:src("%h1= site-name\n"), :context(StringSiteContext.new(:name('Acme'))))
    });

    it 'calls the helper on the context', {
      expect(out).to.match(/'<h1>Acme</h1>'/);
    }

    it 'matches the interpreter output', {
      my $plain = HAML.new.render(:src("%h1= site-name\n"), :context(StringSiteContext.new(:name('Acme'))));
      expect(out).to.be($plain);
    }
  }

  context 'two sources rendered against contexts with different helper sets', {
    let(:haml, { HAML.new(:compiled-cache-dir(fresh-dir())) });

    it 'binds the site helper for the site context', {
      my $out = haml.render-cached(:src("%h1= site-name\n"), :context(StringSiteContext.new(:name('Acme'))));
      expect($out).to.match(/'<h1>Acme</h1>'/);
    }

    it 'binds the greeting helper for the greet context', {
      my $out = haml.render-cached(:src("%h1= greeting\n"), :context(StringGreetContext.new(:who('World'))));
      expect($out).to.match(/'<h1>Hello, World</h1>'/);
    }
  }

  context 'the cache key factors in the context helper names', {
    let(:src, { "%h1 hi\n" });

    it 'gives different keys for contexts with different helper sets', {
      my $site  = HAML.new.compiled-cache-key(:src(src), :context(StringSiteContext.new(:name('Acme'))));
      my $greet = HAML.new.compiled-cache-key(:src(src), :context(StringGreetContext.new(:who('World'))));
      expect($site).to.not.be($greet);
    }

    it 'gives a different key than a render with no context', {
      my $site = HAML.new.compiled-cache-key(:src(src), :context(StringSiteContext.new(:name('Acme'))));
      my $bare = HAML.new.compiled-cache-key(:src(src));
      expect($site).to.not.be($bare);
    }
  }
};
