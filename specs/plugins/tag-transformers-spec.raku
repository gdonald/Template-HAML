use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Node;
use Template::HAML::Tag;
use Template::HAML::TagTransformers;

describe 'tag transformer registry', {
  context 'defaults', {
    it 'has no transformers registered by default', {
      clear-tag-transformers();
      expect(tag-transformer-count()).to.be(0);
      expect(tag-transformer-names().elems).to.be(0);
      expect(has-tag-transformer('card')).to.be-falsy;
      expect(lookup-tag-transformer('card').defined).to.be-falsy;
    }
  }

  context 'registration', {
    it 'transforms %card to <div class="card"> and supports lookup', {
      clear-tag-transformers();
      register-tag-transformer :name<card>, :handler(-> $n {
        $n.object.name = 'div';
        $n.object.attrs.push: 'class' => 'card';
        $n;
      });

      expect(HAML.render(:src("%card hi\n"))).to.eq(qq{<div class='card'>hi</div>\n});

      expect(has-tag-transformer('card')).to.be-truthy;
      expect(tag-transformer-count()).to.be(1);
      expect(tag-transformer-names()[0]).to.be('card');
      expect(lookup-tag-transformer('card').defined).to.be-truthy;

      clear-tag-transformer('card');
      expect(has-tag-transformer('card')).to.be-falsy;
    }
  }

  context 'pass-through', {
    it 'tags without a registered transformer pass through unchanged', {
      clear-tag-transformers();
      register-tag-transformer :name<card>, :handler(-> $n {
        $n.object.name = 'div';
        $n.object.attrs.push: 'class' => 'card';
        $n;
      });

      expect(HAML.render(:src("%p hi\n"))).to.eq("<p>hi</p>\n");

      clear-tag-transformers();
    }
  }

  context 'nested transformation', {
    it 'transforms nested tags', {
      clear-tag-transformers();
      register-tag-transformer :name<card>, :handler(-> $n {
        $n.object.name = 'div';
        $n.object.attrs.push: 'class' => 'card';
        $n;
      });

      expect(HAML.render(:src("%section\n  %card\n    hello\n"))).to.eq(
        "<section>\n  <div class='card'>\n    hello\n  </div>\n</section>\n"
      );

      clear-tag-transformers();
    }
  }

  context 'duplicate names', {
    it 'replaces handler when registering with the same name', {
      clear-tag-transformers();
      register-tag-transformer :name<x>, :handler(-> $n { $n.object.name = 'a'; $n });
      expect(HAML.render(:src("%x hi\n"))).to.eq("<a>hi</a>\n");

      register-tag-transformer :name<x>, :handler(-> $n { $n.object.name = 'b'; $n });
      expect(HAML.render(:src("%x hi\n"))).to.eq("<b>hi</b>\n");
      expect(tag-transformer-count()).to.be(1);

      clear-tag-transformers();
    }
  }

  context 'clear-tag-transformer', {
    it 'removes a single transformer by name', {
      clear-tag-transformers();
      register-tag-transformer :name<a>, :handler(-> $n { $n });
      register-tag-transformer :name<b>, :handler(-> $n { $n });
      expect(tag-transformer-count()).to.be(2);

      expect(clear-tag-transformer('a')).to.be-truthy;
      expect(tag-transformer-count()).to.be(1);
      expect(tag-transformer-names()[0]).to.be('b');
      expect(clear-tag-transformer('a')).to.be-falsy;

      clear-tag-transformers();
    }
  }

  context 'clear-tag-transformers return value', {
    it 'returns the count removed', {
      clear-tag-transformers();
      register-tag-transformer :name<a>, :handler(-> $n { $n });
      register-tag-transformer :name<b>, :handler(-> $n { $n });
      expect(clear-tag-transformers()).to.be(2);
      expect(clear-tag-transformers()).to.be(0);
    }
  }

  context 'handler returning replacement Node', {
    it 'replaces the original node and preserves children', {
      clear-tag-transformers();
      register-tag-transformer :name<card>, :handler(-> $n {
        my $tag = Tag.new(
          :name<div>,
          :indent($n.object.indent),
          :line($n.object.line),
          :column($n.object.column),
          :attrs(['class' => 'card', 'data-role' => 'card']),
          :content($n.object.content),
        );
        my $new = Node.new(:object($tag));
        $new.add-child($_) for $n.children;
        $new;
      });

      expect(HAML.render(:src("%card hi\n"))).to.eq(
        qq{<div class='card' data-role='card'>hi</div>\n}
      );

      expect(HAML.render(:src("%card\n  %p inside\n"))).to.eq(
        "<div class='card' data-role='card'>\n  <p>inside</p>\n</div>\n"
      );

      clear-tag-transformers();
    }
  }

  context 'replacing handlers by name', {
    it 'second registration replaces first', {
      clear-tag-transformers();
      register-tag-transformer :name<dupe>, :handler(-> $n {
        $n.object.name = 'first';
        $n;
      });
      expect(HAML.render(:src("%dupe hi\n"))).to.eq("<first>hi</first>\n");

      register-tag-transformer :name<dupe>, :handler(-> $n {
        $n.object.name = 'second';
        $n;
      });
      expect(HAML.render(:src("%dupe hi\n"))).to.eq("<second>hi</second>\n");

      clear-tag-transformers();
    }
  }

  context 'cached/compiled path', {
    it 'runs through render-cached and compile-source-to-raku', {
      clear-tag-transformers();
      register-tag-transformer :name<card>, :handler(-> $n {
        $n.object.name = 'div';
        $n.object.attrs.push: 'class' => 'card';
        $n;
      });

      my $tmp = $*TMPDIR.add('haml-tag-xform-' ~ $*PID ~ '-' ~ time);
      $tmp.mkdir;
      my $haml = HAML.new(:compiled-cache-dir($tmp));
      expect($haml.render-cached(:src("%card hi\n"))).to.eq(
        qq{<div class='card'>hi</div>\n}
      );
      $haml.clear-compiled-cache;

      expect(HAML.compile-source-to-raku(:src("%card hi\n")).contains('"div"')).to.be(True);

      for $tmp.dir(:r) -> $f { $f.unlink if $f.f }
      $tmp.rmdir if $tmp.e;
      clear-tag-transformers();
    }
  }

  context 'no-op cases', {
    it 'leaves empty source and unrelated tags untouched', {
      clear-tag-transformers();
      register-tag-transformer :name<wrapped>, :handler(-> $n {
        $n.object.name = 'span';
        $n;
      });

      expect(HAML.render(:src(""))).to.eq("");
      expect(HAML.render(:src("%p hi\n"))).to.eq("<p>hi</p>\n");

      clear-tag-transformers();
    }

    it 'renders unaffected when no transformers registered', {
      clear-tag-transformers();
      expect(HAML.render(:src("%p hi\n"))).to.eq("<p>hi</p>\n");
    }
  }
}
