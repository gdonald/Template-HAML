use lib 'lib';
use BDD::Behave;
use Template::HAML;

describe 'implicit div shorthand', {
  it '.foo at line start renders as div with class', {
    expect(HAML.render(:src(".foo\n"))).to.eq("<div class='foo'></div>\n");
  }

  it '#bar at line start renders as div with id', {
    expect(HAML.render(:src("#bar\n"))).to.eq("<div id='bar'></div>\n");
  }

  it '.foo.bar merges classes', {
    expect(HAML.render(:src(".foo.bar\n"))).to.eq("<div class='foo bar'></div>\n");
  }

  it '.a.b.c merges three classes', {
    expect(HAML.render(:src(".a.b.c\n"))).to.eq("<div class='a b c'></div>\n");
  }

  it '.foo#bar produces div with class and id', {
    my $r = HAML.render(:src(".foo#bar\n"));
    expect($r.starts-with('<div ')).to.be-truthy;
    expect($r.ends-with("></div>\n")).to.be-truthy;
    expect($r).to.include("class='foo'");
    expect($r).to.include("id='bar'");
  }

  it '#bar.foo produces div with class and id', {
    my $r = HAML.render(:src("#bar.foo\n"));
    expect($r.starts-with('<div ')).to.be-truthy;
    expect($r.ends-with("></div>\n")).to.be-truthy;
    expect($r).to.include("class='foo'");
    expect($r).to.include("id='bar'");
  }

  it 'class shorthand alone populates class', {
    expect(HAML.render(:src(".x\n"))).to.include("class='x'");
  }

  it 'id shorthand alone populates id', {
    expect(HAML.render(:src("#y\n"))).to.include("id='y'");
  }
}
