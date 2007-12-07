#!/usr/bin/python2.5

import web
web.config.db_parameters = dict(dbn='sqlite', db='/opt/apache/CoGe/data/sqlite/pair_tracking.db')

urls = (
    '/genespace/(.*)', 'genespace'
)


class genespace(object):
    def GET(self, id):
        pairs = web.select(['genespace','pair', 'location'], where=web.db.sqlwhere({ 'genespace.genespace_id' : id }) 
                + ' AND pair.genespace_id = genespace.genespace_id AND location.pair_id = pair.pair_id' )

        for g in pairs:
            print g

application = web.wsgifunc(web.webpyfunc(urls, globals()))
