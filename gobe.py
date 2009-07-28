#!/usr/bin/python

import web
import os
import sqlite3
import simplejson
import urllib

TMPDIR = "/opt/apache/CoGe/tmp/GEvo/"
if not os.path.exists(TMPDIR):
    TMPDIR = os.path.join(os.path.dirname(__file__), "tmp")
DBTMPL = os.path.join(TMPDIR, "%s.sqlite")



def getdb(dbname):
    db = sqlite3.connect(DBTMPL % dbname)
    db.row_factory = sqlite3.Row
    return db


class info(object):
    def GET(self, dbname):
        web.header('Content-type', 'text/javascript')
        db = getdb(dbname)
        c = db.cursor()
        c.execute("SELECT * FROM image_info order by display_id")

        data = {}
        for row in c:
            data[row['display_id']] = {}
            # TODO: see why the perl wraps this dict like: {'img': dict }

            ks = row.keys()
            data[row['display_id']]['img'] = dict(
                image_name=row['iname'],
                title=row['title'],
                width=row['px_width'],
                bpmin=row['bpmin'],
                bpmax=row['bpmax'],
                id=row['id'])

        c.execute("SELECT min(xmin) as min, max(xmax) as max, image_id FROM image_data WHERE type='anchor' GROUP BY image_id ORDER BY image_id")
        for anchor in c:
            data[anchor['image_id']]['anchor'] = dict(
                max=anchor['max'],
                min=anchor['min'])

        result = {}
        for i, did in enumerate(sorted(data)):
            img = data[did]['img']
            name = img['image_name']
            anc = data[did]['anchor']
            if not name in result: result[name] = {}
            result[name] = dict(
                title=img['title'],
                i=i,
                extents=dict(
                    img_width=img['width'],
                    bpmin=img['bpmin'],
                    bpmax=img['bpmax']),
                anchors=dict(
                    idx=img['id'],
                    xmin=anc['min'],
                    xmax=anc['max'])
                )
        return simplejson.dumps(result)

class follow(object):
    def GET(self, dbname):
        db = getdb(dbname)


class query(object):
    def GET(self, dbname):
        db = getdb(dbname)
        c = db.cursor()
        img = web.input(img=None).img

        if web.input(bbox=None).bbox:
            bbox = map(float, web.input().bbox.split(","))
            c.execute("""SELECT * FROM image_data WHERE ? + 1 > xmin AND ? - 1 < xmax AND 
                      ? - 1 > ymin AND ? + 1 < ymax AND image_id = ? AND pair_id != -99 AND type = 'HSP'""", \
                      (bbox[2], bbox[0], bbox[3], bbox[1], img))
        elif web.input(all=None).all:
            c.execute("""SELECT distinct(image_track) as image_track FROM image_data WHERE ? 
                      BETWEEN ymin AND ymax AND image_id = ? ORDER BY 
                      ABS(image_track) DESC""", (float(web.input().y), img))
            track = c.fetchone()['image_track']
            c.execute("""SELECT id, xmin, xmax, ymin, ymax, image_id, image_track, pair_id, color FROM image_data 
                    WHERE ( (image_track = ?) or (image_track = (? * -1) ) ) 
                    and image_id = ? and pair_id != -99 and type = 'HSP'""", (track, track, img))

        else: # point query.
            x = float(web.input().x)
            y = float(web.input().y)
            c.execute("""SELECT * FROM image_data WHERE ? + 3 > xmin AND ? - 3
                      < xmax AND ? BETWEEN ymin and ymax and image_id = ?""", 
                      (x, x, y, img))

        c2 = db.cursor()
        # now iterate over the cursor
        results = []
        for result in c:
            c2.execute("SELECT id, xmin, xmax, ymin, ymax, image_id, image_track, pair_id, color FROM image_data where id = ?", (result['pair_id'], ));
            pair = c2.fetchone()
            anno = result['annotation']
            if anno.startswith('http'):
                try:
                    anno = urllib.urlopen(anno).read()
                except:
                     anno = ""

            f1pts = []
            f2pts = []
            for k in ('xmin', 'ymin', 'xmax', 'ymax'):
                f1pts.append(int(round(result[k])))
                f2pts.append(int(round(pair[k])))
                
            f1pts.append([result['id'], result['image_track']])
            f2pts.append([pair['id'], pair['image_track']])
            results.append(dict(
                # TODO: tell eric to add 'CoGe' to the start of his links.
                link=result['link'],
                annotation = anno,
                # TODO has_pair
                has_pair= True,
                color=(result['color'] or pair['color']).replace('#', '0x'),
                features={
                    'key%i' % result['image_id']: f1pts,
                    'key%i' % pair['image_id']: f2pts}
            ))
        web.header('Content-type', 'text/javascript')
        return simplejson.dumps(results)

urls = (
    '/info/([^\/]+)/', 'info',
    '/follow/([^\/]+)/', 'follow',
    '/query/([^\/]+)/', 'query',
)


app = web.application(urls, locals())
application = app.wsgifunc()

if __name__ == "__main__":
    app.run()
