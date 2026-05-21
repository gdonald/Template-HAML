use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Node;
use Template::HAML::Tag;
use Template::HAML::Visitor;

describe 'AST visitor registry', {
  context 'defaults', {
    it 'has no visitors registered by default', {
      clear-visitors();
      expect(visitor-count()).to.be(0);
      expect(visitor-names().elems).to.be(0);
      expect(has-visitor('any')).to.be-falsy;
    }
  }

  context 'registration and invocation', {
    it 'invokes a registered visitor on render and clears it', {
      clear-visitors();
      my $calls = 0;
      register-visitor :handler(-> $tree {
        $calls++;
        $tree;
      });

      HAML.render(:src("%p hi\n"));
      expect($calls).to.be(1);
      expect(visitor-count()).to.be(1);

      clear-visitors();
      expect($calls).to.be(1);
      HAML.render(:src("%p hi\n"));
      expect($calls).to.be(1);
    }
  }

  context 'named visitors', {
    it 'mutates Tag names in place and is discoverable by name', {
      clear-visitors();
      register-visitor :name<rename>, :handler(-> $tree {
        walk-tree($tree, -> $n {
          if $n.object ~~ Tag && $n.object.name eq 'oldtag' {
            $n.object.name = 'newtag';
          }
        });
        $tree;
      });

      expect(HAML.render(:src("%oldtag hi\n"))).to.eq("<newtag>hi</newtag>\n");
      expect(has-visitor('rename')).to.be-truthy;
      expect(visitor-names().elems).to.be(1);
      expect(visitor-names()[0]).to.be('rename');

      expect(clear-visitor('rename')).to.be-truthy;
      expect(has-visitor('rename')).to.be-falsy;
      expect(clear-visitor('rename')).to.be-falsy;
    }
  }

  context 'walk-tree', {
    it 'visits every Tag in the tree', {
      clear-visitors();
      my @seen-names;
      register-visitor :handler(-> $tree {
        walk-tree($tree, -> $n {
          @seen-names.push: $n.object.name if $n.object ~~ Tag;
        });
        $tree;
      });

      HAML.render(:src(q:to/HAML/));
      %ul
        %li one
        %li two
      HAML

      expect(@seen-names.sort.join(',')).to.be('li,li,ul');
      clear-visitors();
    }
  }

  context 'registration order', {
    it 'runs visitors in registration order', {
      clear-visitors();
      my @order;
      register-visitor :name<first>,  :handler(-> $t { @order.push: 'first';  $t });
      register-visitor :name<second>, :handler(-> $t { @order.push: 'second'; $t });
      register-visitor :name<third>,  :handler(-> $t { @order.push: 'third';  $t });

      HAML.render(:src("%p hi\n"));
      expect(@order.join(',')).to.be('first,second,third');
      expect(visitor-count()).to.be(3);

      clear-visitors();
    }
  }

  context 'duplicate names', {
    it 'replaces handler when registering with the same name', {
      clear-visitors();
      register-visitor :name<dupe>, :handler(-> $t {
        walk-tree($t, -> $n {
          $n.object.name = 'v1' if $n.object ~~ Tag;
        });
        $t;
      });
      expect(HAML.render(:src("%p hi\n"))).to.eq("<v1>hi</v1>\n");

      register-visitor :name<dupe>, :handler(-> $t {
        walk-tree($t, -> $n {
          $n.object.name = 'v2' if $n.object ~~ Tag;
        });
        $t;
      });
      expect(HAML.render(:src("%p hi\n"))).to.eq("<v2>hi</v2>\n");
      expect(visitor-count()).to.be(1);
      clear-visitors();
    }
  }

  context 'attribute injection', {
    it 'injects attributes on every tag and merges with existing class', {
      clear-visitors();
      register-visitor :name<add-class>, :handler(-> $t {
        walk-tree($t, -> $n {
          if $n.object ~~ Tag {
            my $obj = $n.object;
            my $idx = $obj.find-attr-index('class');
            if $idx.defined {
              my $existing = $obj.attrs[$idx].value;
              $obj.attrs[$idx] = 'class' => "$existing visited";
            } else {
              $obj.attrs.push: 'class' => 'visited';
            }
          }
        });
        $t;
      });

      expect(HAML.render(:src("%p hi\n"))).to.eq(qq{<p class='visited'>hi</p>\n});
      expect(HAML.render(:src("%p.named hi\n"))).to.eq(qq{<p class='named visited'>hi</p>\n});

      clear-visitor('add-class');
    }
  }

  context 'anonymous visitors', {
    it 'applies but is not listed in visitor-names', {
      clear-visitors();
      register-visitor :handler(-> $t {
        walk-tree($t, -> $n {
          $n.object.name = 'em' if $n.object ~~ Tag && $n.object.name eq 'b';
        });
        $t;
      });

      expect(HAML.render(:src("%b strong\n"))).to.eq("<em>strong</em>\n");
      expect(visitor-count()).to.be(1);
      expect(visitor-names().elems).to.be-falsy;

      clear-visitors();
    }
  }

  context 'no visitors', {
    it 'renders unaffected when no visitors are registered', {
      clear-visitors();
      expect(HAML.render(:src("%p hi\n"))).to.eq("<p>hi</p>\n");
    }
  }

  context 'tree passed to visitor', {
    it 'receives a non-empty tree', {
      clear-visitors();
      my $original-passed;
      register-visitor :handler(-> $t {
        $original-passed = $t.children.elems > 0;
        $t;
      });
      HAML.render(:src("%p one\n%p two\n"));
      expect($original-passed).to.be-truthy;
      clear-visitors();
    }
  }

  context 'clear-visitors return value', {
    it 'returns the count it removed', {
      clear-visitors();
      register-visitor :name<noop>, :handler(-> $t { $t });
      expect(clear-visitors()).to.be(1);
      expect(clear-visitors()).to.be(0);
    }
  }
}
