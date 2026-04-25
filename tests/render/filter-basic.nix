{ pkgs, libnet, nftlib }:

let
  inherit (pkgs) lib;
  h = import ../harness.nix { inherit pkgs libnet nftlib; };

  filterRenderer = import ../../modules/pipeline/renderers/filter.nix {
    inherit lib nftlib;
  };

  mkResolved = rule: {
    kind = "filter";
    name = "test";
    tableName = "main";
    chain = "input";
    family = "inet";
    inherit rule;
  };
  baseMatch = {
    srcAddresses.ipv4 = [ ];
    srcAddresses.ipv6 = [ ];
    dstAddresses.ipv4 = [ ];
    dstAddresses.ipv6 = [ ];
    srcSet = null;
    dstSet = null;
    srcPorts.tcp = [ ];
    srcPorts.udp = [ ];
    dstPorts.tcp = [ ];
    dstPorts.udp = [ ];
    protocol = null;
    tcpFlags = null;
    ct.state = [ ];
    ct.direction = null;
    mark = null;
    extraMatch = [ ];
  };
  baseRule = {
    enable = true; comment = null; priority = null;
    match = baseMatch;
    counter = null; log = null; limit = null; quota = null;
    ctHelper = null; ctTimeout = null; ctExpectation = null;
    synproxy = null; secmark = null; flowtable = null; tunnel = null;
    meter = null; connectionLimit = null; extraStatements = [ ];
    verdict = null; jumpTo = null; gotoTo = null;
    from = [ ]; to = [ ]; tables = null;
  };

  render = rule: filterRenderer { resolvedRule = mkResolved rule; };
in
  h.runTests {
    testTcpDportMatch = {
      expr = lib.elemAt (render (baseRule // {
        match = baseMatch // { dstPorts.tcp = [ 22 ]; };
        verdict = "accept";
      })) 0;
      expected = {
        match = {
          left = { payload = { protocol = "tcp"; field = "dport"; }; };
          right = { set = [ 22 ]; };
          op = "in";
        };
      };
    };

    testAcceptVerdict = {
      expr = lib.last (render (baseRule // {
        match = baseMatch // { dstPorts.tcp = [ 22 ]; };
        verdict = "accept";
      }));
      expected = { accept = null; };
    };

    testDropVerdict = {
      expr = lib.last (render (baseRule // { verdict = "drop"; }));
      expected = { drop = null; };
    };

    testCounterAuto = {
      expr =
        let r = render (baseRule // { counter = true; verdict = "accept"; }); in
        lib.elemAt r 0;
      expected = { counter = null; };
    };

    testCounterByName = {
      expr =
        let r = render (baseRule // { counter = "my-counter"; verdict = "accept"; }); in
        lib.elemAt r 0;
      expected = { counter = "my-counter"; };
    };

    testJumpVerdict = {
      expr = lib.last (render (baseRule // { jumpTo = "my-chain"; }));
      expected = { jump = { target = "my-chain"; }; };
    };

    testFlowtableEnrol = {
      expr =
        let r = render (baseRule // {
          flowtable = "offload";
          match = baseMatch // { ct.state = [ "established" "related" ]; };
          verdict = "accept";
        }); in
        builtins.elem { flow = { flowtable = "@offload"; }; } r;
      expected = true;
    };

    testCtHelperRef = {
      expr =
        let r = render (baseRule // {
          ctHelper = "ftp";
          match = baseMatch // { dstPorts.tcp = [ 21 ]; };
          verdict = "accept";
        }); in
        builtins.elem { "ct helper" = "@ftp"; } r;
      expected = true;
    };

    testEmptyRule = {
      expr = render (baseRule // { });
      expected = [ ];
    };

    testCtStateMatch = {
      expr = lib.elemAt (render (baseRule // {
        match = baseMatch // { ct.state = [ "established" "related" ]; };
        verdict = "accept";
      })) 0;
      expected = {
        match = {
          left = { ct = { key = "state"; }; };
          right = { set = [ "established" "related" ]; };
          op = "in";
        };
      };
    };
  }
