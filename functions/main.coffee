functions = require('firebase-functions')
admin = require('firebase-admin')
Crawler = require("crawler");
auth = require 'basic-auth'
_ = require 'underscore'
admin.initializeApp functions.config().firebase
cors = require('cors')(origin: true)


# // Create and Deploy Your First Cloud Functions
# // https://firebase.google.com/docs/functions/write-firebase-functions


# http://www.ign.com/reviews/games/reviews-ajax?startIndex=25
exports.crawl_ign = functions.https.onRequest (request, response) ->
  cors request, response, =>
    admin.database().ref("/config/ign/last_review").once 'value', (snap) ->
      last_review = null or snap.val()
      crawl = new Crawler {
        rotateUA: true
        userAgent: [
          'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36'
          'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2227.0 Safari/537.36'
          'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:40.0) Gecko/20100101 Firefox/40.1'
        ]
        maxConnections: 10
        callback: (error, res, done) ->
          if error
            console.log error
          else
            url_process = res.request.uri
            $ = res.$

            switch true

              when /\/games\/reviews-ajax/.test url_process

                # Iterate List
                reviews = $('.scoreBox-link')
                for item in $('.scoreBox-link')
                  review = $(item).attr 'href'
                  return done() if review is last_review
                  crawl.queue $(item).attr 'href'

                # Get Next Page
                more = $('#is-more-reviews').attr('data-start')
                if more
                  crawl.queue "http://www.ign.com/reviews/games/reviews-ajax?startIndex=#{more}"
                  last_review = reviews[0] if more is '25'
                done()

              when /articles/.test url_process
                $author = $('.author-field .author-field .author-name a')

                # game stuff
                game_score = $('.score-wrapper [itemprop="ratingValue"]').text()
                game_title = $('title').text().replace('Revew - IGN', '').trim()
                game_review = url_process
                game_uid = encodeURIComponent(game_title)
                game_image = $('meta[property="og:image"]').attr 'content'

                # author stuff
                author_name = $author.text()
                author_uid = author_url.match(/ign\.com\/(.+)\/?/)[1]
                author_url = $author.attr 'href'
                author_image = $('.author-avatar img').attr 'src'
                author_employer = 'IGN'

                admin.database().ref("/reviewers/#{author_employer}/#{author_uid}").once 'value', (snap) ->
                  current = snap.val() or {}
                  current.games ?= {}
                  current.author ?= {
                    name: author_name
                    url: author_url
                    image: author_image
                  }
                  current.games[game_uid] = {
                    game_title: game_title
                    score: game_score
                    image: game_image
                    link: game_review
                  }
                  snap.ref.set current, done
      }

      crawl.queue("http://www.ign.com/reviews/games/reviews-ajax?startIndex=0")
      crawl.on 'drain', ->
        admin.database().ref("/config/ign/last_review").set last_review, ->
          return response.send('finished crawl')









