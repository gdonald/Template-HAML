use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Config;

describe ':javascript and :css cdata + mime-type behavior', {
  it 'XHTML :javascript wraps in CDATA and adds type', {
    my $cfg = Template::HAML::Config.new(:format<xhtml>);
    my $r   = HAML.render(:src(q:to/HAML/), :config($cfg));
    :javascript
      alert(1);
    HAML
    expect($r).to.eq("<script type='text/javascript'>\n  //<![CDATA[\n  alert(1);\n  //]]>\n</script>\n");
  }

  it 'XHTML :css wraps in CDATA and adds type', {
    my $cfg = Template::HAML::Config.new(:format<xhtml>);
    my $r = HAML.render(:src(q:to/HAML/), :config($cfg));
    :css
      body { color: red; }
    HAML
    expect($r).to.eq("<style type='text/css'>\n  /*<![CDATA[*/\n  body \{ color: red; \}\n  /*]]>*/\n</style>\n");
  }

  it 'cdata=True in HTML5 forces CDATA on :javascript', {
    my $cfg = Template::HAML::Config.new(:cdata);
    my $r = HAML.render(:src(q:to/HAML/), :config($cfg));
    :javascript
      alert(1);
    HAML
    expect($r).to.eq("<script>\n  //<![CDATA[\n  alert(1);\n  //]]>\n</script>\n");
  }

  it 'cdata=True in HTML5 forces CDATA on :css', {
    my $cfg = Template::HAML::Config.new(:cdata);
    my $r = HAML.render(:src(q:to/HAML/), :config($cfg));
    :css
      body { color: red; }
    HAML
    expect($r).to.eq("<style>\n  /*<![CDATA[*/\n  body \{ color: red; \}\n  /*]]>*/\n</style>\n");
  }

  it 'mime-type overrides default type attr', {
    my $cfg = Template::HAML::Config.new(:mime-type<application/javascript>);
    my $r = HAML.render(:src(q:to/HAML/), :config($cfg));
    :javascript
      go();
    HAML
    expect($r).to.eq("<script type='application/javascript'>\n  go();\n</script>\n");
  }

  it 'HTML5 default :javascript has no type attr and no CDATA', {
    my $r = HAML.render(:src(q:to/HAML/));
    :javascript
      alert(1);
    HAML
    expect($r).to.eq("<script>\n  alert(1);\n</script>\n");
  }

  it 'HTML5 default :css has no type attr', {
    my $r = HAML.render(:src(q:to/HAML/));
    :css
      p { }
    HAML
    expect($r).to.eq("<style>\n  p \{ \}\n</style>\n");
  }

  it 'XHTML empty :javascript still has type', {
    my $cfg = Template::HAML::Config.new(:format<xhtml>);
    my $r = HAML.render(:src(":javascript\n"), :config($cfg));
    expect($r).to.eq("<script type='text/javascript'></script>\n");
  }

  it 'attr-quote affects type attr quoting', {
    my $cfg = Template::HAML::Config.new(:format<xhtml>, :attr-quote('"'));
    my $r = HAML.render(:src(q:to/HAML/), :config($cfg));
    :javascript
      go();
    HAML
    expect($r).to.eq("<script type=\"text/javascript\">\n  //<![CDATA[\n  go();\n  //]]>\n</script>\n");
  }

  it 'mime-type overrides XHTML default for :javascript', {
    my $cfg = Template::HAML::Config.new(:format<xhtml>, :mime-type<application/ecmascript>);
    my $r = HAML.render(:src(q:to/HAML/), :config($cfg));
    :javascript
      go();
    HAML
    expect($r).to.eq("<script type='application/ecmascript'>\n  //<![CDATA[\n  go();\n  //]]>\n</script>\n");
  }

  it 'mime-type overrides default for :css', {
    my $cfg = Template::HAML::Config.new(:format<xhtml>, :mime-type<text/x-scss>);
    my $r = HAML.render(:src(q:to/HAML/), :config($cfg));
    :css
      p { }
    HAML
    expect($r).to.eq("<style type='text/x-scss'>\n  /*<![CDATA[*/\n  p \{ \}\n  /*]]>*/\n</style>\n");
  }

  it 'cdata=True with XHTML does not double-wrap', {
    my $cfg = Template::HAML::Config.new(:format<xhtml>, :cdata);
    my $r = HAML.render(:src(q:to/HAML/), :config($cfg));
    :javascript
      go();
    HAML
    expect($r).to.eq("<script type='text/javascript'>\n  //<![CDATA[\n  go();\n  //]]>\n</script>\n");
  }
}
