const PERMISSIVE_ALLOWLIST = Object.freeze([
  'MIT',
  'Apache-2.0',
  'BSD-2-Clause',
  'BSD-3-Clause',
  'ISC',
  'CC0-1.0',
  'Unlicense',
  'Vim',
  'Zlib',
]);

const DETECTORS = [
  {
    id: 'Apache-2.0',
    test: (t) => /Apache License[\s\S]{0,200}Version 2\.0/i.test(t),
  },
  {
    id: 'BSD-3-Clause',
    test: (t) =>
      /BSD 3-Clause|Redistribution and use in source and binary forms/i.test(t) &&
      /3\. Neither the name of/i.test(t),
  },
  {
    id: 'BSD-2-Clause',
    test: (t) =>
      /BSD 2-Clause|Redistribution and use in source and binary forms/i.test(t) &&
      !/3\. Neither the name of/i.test(t),
  },
  {
    id: 'MIT',
    test: (t) =>
      /\bMIT License\b/i.test(t) ||
      /Permission is hereby granted, free of charge/i.test(t),
  },
  {
    id: 'ISC',
    test: (t) =>
      /ISC License|Permission to use, copy, modify, and\/or distribute this software/i.test(t),
  },
  {
    id: 'CC0-1.0',
    test: (t) => /Creative Commons.*CC0|\bCC0 1\.0\b/i.test(t),
  },
  {
    id: 'Unlicense',
    test: (t) => /This is free and unencumbered software released into the public domain/i.test(t),
  },
  {
    id: 'Vim',
    test: (t) => /VIM LICENSE/i.test(t),
  },
  {
    id: 'Zlib',
    test: (t) => /\bzlib\b[\s\S]{0,200}altered from any source distribution/i.test(t),
  },
];

const DISALLOWED = [
  {
    id: 'GPL',
    test: (t) => /GNU GENERAL PUBLIC LICENSE/i.test(t),
  },
  {
    id: 'LGPL',
    test: (t) => /GNU LESSER GENERAL PUBLIC LICENSE/i.test(t),
  },
  {
    id: 'AGPL',
    test: (t) => /GNU AFFERO GENERAL PUBLIC LICENSE/i.test(t),
  },
  {
    id: 'MPL',
    test: (t) => /Mozilla Public License/i.test(t),
  },
  {
    id: 'SSPL',
    test: (t) => /Server Side Public License/i.test(t),
  },
];

export function detectSpdxId(text) {
  for (const rule of DISALLOWED) {
    if (rule.test(text)) return null;
  }
  for (const rule of DETECTORS) {
    if (rule.test(text)) return rule.id;
  }
  return null;
}

export function isPermissiveSpdx(id) {
  return PERMISSIVE_ALLOWLIST.includes(id);
}

export function allowlist() {
  return [...PERMISSIVE_ALLOWLIST];
}
