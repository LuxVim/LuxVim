import { test } from 'node:test';
import assert from 'node:assert/strict';
import { detectSpdxId, isPermissiveSpdx } from '../lib/spdx.mjs';

const MIT_TEXT = `MIT License

Copyright (c) 2024 Example

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.`;

const APACHE_TEXT = `                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION`;

const BSD3_TEXT = `BSD 3-Clause License

Copyright (c) 2024, Example
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.`;

const GPL_TEXT = `                    GNU GENERAL PUBLIC LICENSE
                       Version 3, 29 June 2007`;

test('detectSpdxId: MIT', () => {
  assert.equal(detectSpdxId(MIT_TEXT), 'MIT');
});

test('detectSpdxId: Apache-2.0', () => {
  assert.equal(detectSpdxId(APACHE_TEXT), 'Apache-2.0');
});

test('detectSpdxId: BSD-3-Clause', () => {
  assert.equal(detectSpdxId(BSD3_TEXT), 'BSD-3-Clause');
});

test('detectSpdxId: GPL returns null (disallowed)', () => {
  assert.equal(detectSpdxId(GPL_TEXT), null);
});

test('detectSpdxId: unknown returns null', () => {
  assert.equal(detectSpdxId('Random text with no license keywords'), null);
});

test('isPermissiveSpdx: MIT is permissive', () => {
  assert.equal(isPermissiveSpdx('MIT'), true);
});

test('isPermissiveSpdx: Apache-2.0 is permissive', () => {
  assert.equal(isPermissiveSpdx('Apache-2.0'), true);
});

test('isPermissiveSpdx: GPL-3.0 is not permissive', () => {
  assert.equal(isPermissiveSpdx('GPL-3.0'), false);
});

test('isPermissiveSpdx: null is not permissive', () => {
  assert.equal(isPermissiveSpdx(null), false);
});
