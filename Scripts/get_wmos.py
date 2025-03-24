#!/usr/bin/env python

import os, re, shutil

numbered_wmo_regex = re.compile(u'_\d\d\d\.wmo$')

paths_to_check = [u'World/wmo/Dungeon']

try:
    os.mkdir('/Users/ckknight/wmo')
except:
    pass

mpqs = [u'common.MPQ', u'common-2.MPQ', u'expansion.MPQ', u'patch.MPQ']

for path in mpqs:
    for path_to_check in paths_to_check:
        if path.endswith(u'.MPQ') and os.path.isdir(u'/Volumes/%s/%s' % (path, path_to_check)):
            for root, dirs, files in os.walk(u'/Volumes/%s/%s' % (path, path_to_check)):
                for f in files:
                    if f.endswith(u'.wmo') and not numbered_wmo_regex.search(f):
                        shutil.copyfile(os.path.join(root, f), '/Users/ckknight/wmo/%s' % f)
                        print os.path.join(root, f)
