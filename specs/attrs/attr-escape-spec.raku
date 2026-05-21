use lib 'lib';
use BDD::Behave;
use Template::HAML;

describe 'attribute value HTML escaping', {
  it 'escapes &', {
    expect(HAML.render(:src(Q[%a{title: 'tom & jerry'}] ~ "\n")))
      .to.eq("<a title='tom &amp; jerry'></a>\n");
  }

  it 'escapes < and >', {
    expect(HAML.render(:src(Q[%a{title: '<script>'}] ~ "\n")))
      .to.eq("<a title='&lt;script&gt;'></a>\n");
  }

  it 'escapes a single quote to &#39;', {
    expect(HAML.render(:src(Q[%a{title: "don't"}] ~ "\n")))
      .to.eq("<a title='don&#39;t'></a>\n");
  }

  it 'escapes a double quote to &quot;', {
    expect(HAML.render(:src(Q[%a{title: 'a "quoted" word'}] ~ "\n")))
      .to.eq("<a title='a &quot;quoted&quot; word'></a>\n");
  }

  it 'escapes combined &, <, > in one value', {
    expect(HAML.render(:src(Q[%a{title: 'a & b < c'}] ~ "\n")))
      .to.eq("<a title='a &amp; b &lt; c'></a>\n");
  }
}
