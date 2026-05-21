use lib 'lib';
use BDD::Behave;
use Template::HAML;

describe 'tag shorthands', {
  it '%tag.class', {
    expect(HAML.render(:src("%tag.class\n"))).to.eq("<tag class='class'></tag>\n");
  }

  it '%tag#id', {
    my $r = HAML.render(:src("%tag#id\n"));
    expect($r.starts-with('<tag ')).to.be-truthy;
    expect($r.ends-with("></tag>\n")).to.be-truthy;
    expect($r).to.include("id='id'");
  }

  it '%tag.class#id', {
    my $r = HAML.render(:src("%a.cls#main\n"));
    expect($r.starts-with('<a ')).to.be-truthy;
    expect($r).to.include("class='cls'");
    expect($r).to.include("id='main'");
  }

  it '%tag#id.class', {
    my $r = HAML.render(:src("%a#main.cls\n"));
    expect($r.starts-with('<a ')).to.be-truthy;
    expect($r).to.include("class='cls'");
    expect($r).to.include("id='main'");
  }

  it '%tag.a.b.c#main', {
    my $r = HAML.render(:src("%a.x.y.z#main\n"));
    expect($r).to.include("class='x y z'");
    expect($r).to.include("id='main'");
  }

  it 'class shorthand merges with attribute hash class', {
    my $r = HAML.render(:src("%a.x\{class: 'y'\}\n"));
    expect($r.contains("class='y x'") || $r.contains("class='x y'")).to.be-truthy;
  }

  it 'multiple class shorthands merge with hash class', {
    my $r = HAML.render(:src("%a.x.y\{class: 'z'\}\n"));
    expect($r).to.include("class=");
    expect($r).to.include('x');
    expect($r).to.include('y');
    expect($r).to.include('z');
  }

  it 'multiple #id shorthands concatenate with underscore', {
    my $r = HAML.render(:src("%a#one#two\n"));
    expect($r).to.include("id='one_two'");
  }

  it 'shorthand id and hash id concatenate with underscore', {
    my $r = HAML.render(:src("%a#one\{id: 'two'\}\n"));
    expect($r).to.include("id='one_two'");
  }

  it 'multiple ids do not raise duplicate-id', {
    expect({ HAML.render(:src("%div#a#b\n")) }).to.not.raise-error;
  }

  it 'duplicate classes are merged', {
    my $r = HAML.render(:src("%a.x.x\n"));
    expect($r).to.include("class='x'");
    expect($r.contains("x x")).to.be-falsy;
  }

  it '%h1.title with content', {
    expect(HAML.render(:src("%h1.title Hello\n"))).to.eq("<h1 class='title'>Hello</h1>\n");
  }
}
