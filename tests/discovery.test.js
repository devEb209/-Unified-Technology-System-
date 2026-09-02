"use strict";
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { classify, TYPE_FROM_HINT, localSubnets } = require("../server/discovery");

test("classify identifica TV por portas Chromecast/Roku", () => {
  assert.equal(classify([{ hint: "chromecast" }]), "tv");
  assert.equal(classify([{ hint: "roku" }]), "tv");
});

test("classify identifica computador por RDP/SSH", () => {
  assert.equal(classify([{ hint: "rdp" }]), "computer");
  assert.equal(classify([{ hint: "ssh" }]), "computer");
});

test("classify identifica impressora", () => {
  assert.equal(classify([{ hint: "printer" }]), "printer");
});

test("TYPE_FROM_HINT cobre dicas principais", () => {
  assert.equal(TYPE_FROM_HINT.plex, "media");
  assert.equal(TYPE_FROM_HINT.mqtt, "iot");
});

test("localSubnets retorna array", () => {
  const nets = localSubnets();
  assert.ok(Array.isArray(nets));
});
