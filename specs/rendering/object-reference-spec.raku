use lib 'lib';
use BDD::Behave;
use Template::HAML;

class User {
  has Int $.id;
  has Str $.name;
}

class BlogPost {
  has Int $.id;
}

class Article {
  has Int $.id;
  has Str $.title;
}

class Thing {
  has Str $.name;
}

class CustomRef {
  has Int $.id;
  method haml-object-ref { 'custom' }
}

class Box {
  has $.id;
  method tag-prefix(Int $n) { "box$n" }
}

my $u   = User.new(:id(42), :name('Greg'));
my $b   = BlogPost.new(:id(7));
my $a   = Article.new(:id(1), :title('Hi'));
my $t   = Thing.new(:name('x'));
my $c   = CustomRef.new(:id(99));
my $box = Box.new(:id(3));

describe 'HAML object reference', {
  it 'object reference: class from type, id from .id', {
    expect(HAML.render(:src(Q!%div[$u]! ~ "\n"), :locals(%(u => $u))))
      .to.eq("<div id='user_42' class='user'></div>\n");
  }

  it 'object reference: prefix form', {
    expect(HAML.render(:src(Q!%div[$u, 'greeting']! ~ "\n"), :locals(%(u => $u))))
      .to.eq("<div id='greeting_user_42' class='greeting_user'></div>\n");
  }

  it 'CamelCase type collapses to snake_case', {
    expect(HAML.render(:src(Q!%article[$b]! ~ "\n"), :locals(%(b => $b))))
      .to.eq("<article id='blog_post_7' class='blog_post'></article>\n");
  }

  it 'obj-ref class prepends to shorthand class', {
    expect(HAML.render(:src(Q!%p.foo[$u]! ~ "\n"), :locals(%(u => $u))))
      .to.eq("<p id='user_42' class='user foo'></p>\n");
  }

  it 'obj-ref id prepends to shorthand id', {
    expect(HAML.render(:src(Q!%p#main[$u]! ~ "\n"), :locals(%(u => $u))))
      .to.eq("<p id='user_42_main' class='user'></p>\n");
  }

  it 'no .id method emits only class', {
    expect(HAML.render(:src(Q!%div[$t]! ~ "\n"), :locals(%(t => $t))))
      .to.eq("<div class='thing'></div>\n");
  }

  it 'obj-ref class prepends to params-hash class', {
    expect(HAML.render(:src(Q!%div[$u]{class: 'active'}! ~ "\n"), :locals(%(u => $u))))
      .to.eq("<div id='user_42' class='user active'></div>\n");
  }

  it 'implicit div with obj-ref', {
    expect(HAML.render(:src(Q!.container[$u]! ~ "\n"), :locals(%(u => $u))))
      .to.eq("<div id='user_42' class='user container'></div>\n");
  }

  it 'obj-ref class merges with multiple shorthand classes', {
    expect(HAML.render(:src(Q!%div.a.b[$u]! ~ "\n"), :locals(%(u => $u))))
      .to.eq("<div id='user_42' class='user a b'></div>\n");
  }

  it 'prefix combines with type name and .id', {
    expect(HAML.render(:src(Q!%section[$a, 'admin']! ~ "\n"), :locals(%(a => $a))))
      .to.eq("<section id='admin_article_1' class='admin_article'></section>\n");
  }

  it 'prefix without .id method', {
    expect(HAML.render(:src(Q!%div[$t, 'g']! ~ "\n"), :locals(%(t => $t))))
      .to.eq("<div class='g_thing'></div>\n");
  }

  it 'obj-ref with text content', {
    expect(HAML.render(:src(Q!%p[$u] Hello! ~ "\n"), :locals(%(u => $u))))
      .to.eq("<p id='user_42' class='user'>Hello</p>\n");
  }

  it 'haml-object-ref method overrides type name', {
    expect(HAML.render(:src(Q!%div[$c]! ~ "\n"), :locals(%(c => $c))))
      .to.eq("<div id='custom_99' class='custom'></div>\n");
  }

  it 'undefined object emits no class or id', {
    expect(HAML.render(:src(Q!%div[$missing]! ~ "\n"), :locals(%(missing => Nil))))
      .to.eq("<div></div>\n");
  }

  it 'implicit div with id shorthand and obj-ref', {
    expect(HAML.render(:src(Q!#wrap[$u]! ~ "\n"), :locals(%(u => $u))))
      .to.eq("<div id='user_42_wrap' class='user'></div>\n");
  }

  it 'obj-ref id prepends to params-hash id', {
    expect(HAML.render(:src(Q!%div[$u]{id: 'x'}! ~ "\n"), :locals(%(u => $u))))
      .to.eq("<div id='user_42_x' class='user'></div>\n");
  }

  it 'obj-ref on self-closing element', {
    expect(HAML.render(:src(Q!%input[$u]/! ~ "\n"), :locals(%(u => $u))))
      .to.eq("<input id='user_42' class='user'>\n");
  }

  it 'obj-ref nested under another tag', {
    expect(HAML.render(:src(Q!%div! ~ "\n" ~ Q!  %p[$u] hi! ~ "\n"), :locals(%(u => $u))))
      .to.eq("<div>\n  <p id='user_42' class='user'>hi</p>\n</div>\n");
  }

  it 'prefix from a local variable', {
    expect(HAML.render(:src(Q!%div[$u, $p]! ~ "\n"), :locals(%(u => $u, p => 'pfx'))))
      .to.eq("<div id='pfx_user_42' class='pfx_user'></div>\n");
  }

  it 'Pair-style prefix uses .key', {
    expect(HAML.render(:src(Q!%div[$u, :greeting]! ~ "\n"), :locals(%(u => $u))))
      .to.eq("<div id='greeting_user_42' class='greeting_user'></div>\n");
  }

  it 'expression with method call and parens as prefix', {
    expect(HAML.render(:src(Q!%div[$box, $box.tag-prefix(1)]! ~ "\n"), :locals(%(box => $box))))
      .to.eq("<div id='box1_box_3' class='box1_box'></div>\n");
  }

  it 'obj-ref with both shorthand class and id', {
    expect(HAML.render(:src(Q!%p.lead#hero[$u]! ~ "\n"), :locals(%(u => $u))))
      .to.eq("<p id='user_42_hero' class='user lead'></p>\n");
  }
}
