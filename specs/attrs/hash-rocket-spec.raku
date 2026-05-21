use lib 'lib';
use BDD::Behave;
use Template::HAML;

describe 'HAML hash rocket attributes', {
  it 'hash rocket with symbol key', {
    expect(HAML.render(:src(Q[%a{:href => '/'}] ~ "\n"))).to.eq("<a href='/'></a>\n");
  }

  it 'hash rocket with single-quoted key', {
    expect(HAML.render(:src(Q[%a{'href' => '/'}] ~ "\n"))).to.eq("<a href='/'></a>\n");
  }

  it 'hash rocket with double-quoted key', {
    expect(HAML.render(:src(Q[%a{"href" => "/"}] ~ "\n"))).to.eq("<a href='/'></a>\n");
  }

  it 'bare and rocket pairs in same hash', {
    expect(HAML.render(:src(Q[%a{href: '/', :title => 'home'}] ~ "\n")))
      .to.eq("<a href='/' title='home'></a>\n");
  }
}
