# Déclare l'abonnement Salat Premium sur App Store Connect.
#
#   ruby scripts/asc_subscription.rb            # lit et dit ce qui manque, n'écrit rien
#   ruby scripts/asc_subscription.rb --apply    # crée ce qui manque
#   ruby scripts/asc_subscription.rb --apply --screenshot chemin/paywall.png
#   ruby scripts/asc_subscription.rb --apply --start 2026-11-23   # changement de prix daté
#
# Ce que ça pose, dans l'ordre, et chaque étape regarde d'abord si c'est déjà
# fait (le script se relance sans rien dupliquer) :
#
#   1. le groupe d'abonnements « Salat Premium » et son nom par langue ;
#   2. l'abonnement mensuel `com.salat.premium.monthly` : l'identifiant est
#      celui de `Store.productID` dans l'app, à la lettre près ;
#   3. son nom et sa description par langue (30 et 45 caractères au plus) ;
#   4. sa disponibilité dans tous les pays, nouveaux pays compris ;
#   5. son prix : 4,99 € en France, qui sert de base, le palier équivalent
#      qu'Apple en déduit partout ailleurs, et 4,99 $ imposé aux États-Unis.
#      Un pays qui avait déjà un prix reçoit le nouveau avec
#      `preserveCurrentPrice: true` : les abonnés en cours gardent le leur ;
#   5 bis. l'offre d'introduction, 3 jours gratuits, dans chaque pays ;
#   6. avec `--screenshot`, la capture du paywall que la revue exige.
#
# Les fiches par langue et la note de revue sont aussi remises à jour
# (PATCH) quand le texte du script a changé.
#
# Ce que le script NE fait PAS, parce que l'API ne le sait pas ou que ce n'est
# pas à lui de le décider :
#
#   - soumettre l'abonnement. Le premier abonnement d'une app part **avec une
#     version de l'app** : sur la page de la version, section « Achats intégrés
#     et abonnements », le cocher avant d'envoyer en revue ;
#   - signer le contrat « Apps payantes » (Accords, taxes et coordonnées
#     bancaires). Sans lui l'abonnement se crée mais ne se charge jamais, ni en
#     bac à sable ni en production : `Product.products` rend une liste vide.
#
# Un identifiant de produit ne se réutilise jamais, même après suppression :
# ne pas le changer « pour voir ».
#
# Même JWT que les autres scripts (`asc_price_free.rb`) : OpenSSL de la stdlib,
# aucune gem. Variables : ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8_PATH
# (`set -a; source ~/.config/ios-testflight-cicd/config.env; set +a`).

require "openssl"
require "base64"
require "json"
require "net/http"
require "digest"

BASE = "https://api.appstoreconnect.apple.com/v1"
APPLY = ARGV.include?("--apply")
SHOT = (i = ARGV.index("--screenshot")) ? ARGV[i + 1] : nil
# Date d'effet d'un CHANGEMENT de prix (AAAA-MM-JJ). Un abonnement déjà
# approuvé refuse un prix sans date (409 STATE_ERROR « Initial price cannot be
# created again after subscription is approved », vu le 22/11/2026) : un
# changement est toujours programmé à une date.
START = (i = ARGV.index("--start")) ? ARGV[i + 1] : nil

GROUP_NAME   = "Salat Premium"
PRODUCT_NAME = "Salat Premium mensuel"
PERIOD       = "ONE_MONTH"
BASE_TERRITORY = "FRA"
# 4,99 € depuis le 22/11/2026 (décision de Sharik : hard paywall, plus de pub).
# C'était 1,99 € du 14/11 au 22/11/2026 ; les abonnés de cette période gardent
# leur prix (preserveCurrentPrice, voir l'étape 5).
PRICE          = 4.99
# Les pays où le palier est imposé au lieu d'être déduit de la France.
FORCED = { "USA" => 4.99 }
# L'offre d'introduction : gratuite, une période de cette durée.
TRIAL = "THREE_DAYS"

# Nom (30 max) et description (45 max) de l'abonnement, par langue de la fiche.
LOCALES = {
  "en-US" => ["Salat Premium", "Full access: prayer, Qur'an, widget"],
  "fr-FR" => ["Salat Premium", "Accès complet : prière, Coran, widget"],
  "ar-SA" => ["Salat Premium", "وصول كامل: الصلاة والقرآن والأداة"]
}

REVIEW_NOTE = "Salat Premium is required to use the app (hard paywall, no ads). " \
              "It unlocks every feature: the prayer lessons, the Qur'an feed, the " \
              "memorisation exercises and the Home Screen widget. New subscribers " \
              "get a 3-day free trial (introductory offer), then the monthly price. " \
              "The paywall is the last screen of the onboarding and opens at every " \
              "launch until a subscription is active; it carries the price, Restore " \
              "Purchases, Terms of Use (Apple standard EULA) and Privacy Policy."

def b64(s) = Base64.urlsafe_encode64(s).delete("=")

def token
  key = OpenSSL::PKey::EC.new(File.read(ENV.fetch("ASC_KEY_P8_PATH")))
  header  = b64({ alg: "ES256", kid: ENV.fetch("ASC_KEY_ID"), typ: "JWT" }.to_json)
  payload = b64({ iss: ENV.fetch("ASC_ISSUER_ID"),
                  exp: Time.now.to_i + 1100,
                  aud: "appstoreconnect-v1" }.to_json)
  der  = key.sign(OpenSSL::Digest.new("SHA256"), "#{header}.#{payload}")
  r, s = OpenSSL::ASN1.decode(der).value.map { |v| v.value.to_s(2).rjust(32, "\x00") }
  "#{header}.#{payload}.#{b64(r + s)}"
end

TOK = token

VERBS = { get: Net::HTTP::Get, post: Net::HTTP::Post, patch: Net::HTTP::Patch }

def call(method, path, body = nil)
  uri = URI(path.start_with?("http") ? path : "#{BASE}/#{path}")
  req = VERBS.fetch(method).new(uri)
  req["Authorization"] = "Bearer #{TOK}"
  if body
    req["Content-Type"] = "application/json"
    req.body = body.to_json
  end
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
  abort("HTTP #{res.code} sur #{method.upcase} #{path}\n#{res.body}") unless [200, 201, 204].include?(res.code.to_i)
  res.body.to_s.empty? ? {} : JSON.parse(res.body)
end

# Toutes les pages d'une liste : l'API en rend 200 au plus et donne la suite
# dans `links.next`.
def all(path)
  data = []
  while path
    page = call(:get, path)
    data.concat(page["data"])
    path = page.dig("links", "next")
  end
  data
end

def rel(type, id) = { data: { type: type, id: id } }

def step(label, missing)
  puts "#{missing ? (APPLY ? '+' : '·') : '='} #{label}#{missing && !APPLY ? '  (à créer)' : ''}"
  missing && APPLY
end

def app_bundle_id
  yml = File.read(File.expand_path("../project.yml", __dir__))
  yml[/PRODUCT_BUNDLE_IDENTIFIER:\s*(\S+)/, 1] or abort("PRODUCT_BUNDLE_IDENTIFIER absent de project.yml")
end

# L'identifiant du produit se lit dans l'app : c'est elle qui le demandera à
# l'App Store, et deux copies finissent par différer.
def product_id
  swift = File.read(File.expand_path("../Salat/Services/Store.swift", __dir__))
  swift[/static let productID = "([^"]+)"/, 1] or abort("Store.productID introuvable")
end

PRODUCT_ID = product_id
puts APPLY ? "Mode écriture." : "Lecture seule (ajouter --apply pour créer)."

apps = call(:get, "apps?filter[bundleId]=#{app_bundle_id}")
abort("Aucune fiche App Store pour #{app_bundle_id}") if apps["data"].empty?
app = apps["data"].first
puts "app : #{app['attributes']['name']} (#{app['id']}), produit #{PRODUCT_ID}"

# 1. Le groupe
group = all("apps/#{app['id']}/subscriptionGroups?limit=200")
        .find { |g| g.dig("attributes", "referenceName") == GROUP_NAME }
if step("groupe « #{GROUP_NAME} »", group.nil?)
  group = call(:post, "subscriptionGroups",
               { data: { type: "subscriptionGroups",
                         attributes: { referenceName: GROUP_NAME },
                         relationships: { app: rel("apps", app["id"]) } } })["data"]
end

if group
  have = all("subscriptionGroups/#{group['id']}/subscriptionGroupLocalizations?limit=200")
         .map { |l| l.dig("attributes", "locale") }
  LOCALES.each do |locale, (name, _)|
    next unless step("  nom du groupe en #{locale}", !have.include?(locale))
    call(:post, "subscriptionGroupLocalizations",
         { data: { type: "subscriptionGroupLocalizations",
                   attributes: { name: name, locale: locale },
                   relationships: { subscriptionGroup: rel("subscriptionGroups", group["id"]) } } })
  end
end

# 2. L'abonnement
sub = group && all("subscriptionGroups/#{group['id']}/subscriptions?limit=200")
              .find { |s| s.dig("attributes", "productId") == PRODUCT_ID }
if step("abonnement #{PRODUCT_ID} (mensuel)", sub.nil?)
  sub = call(:post, "subscriptions",
             { data: { type: "subscriptions",
                       attributes: { name: PRODUCT_NAME, productId: PRODUCT_ID,
                                     subscriptionPeriod: PERIOD, groupLevel: 1,
                                     familySharable: false, reviewNote: REVIEW_NOTE },
                       relationships: { group: rel("subscriptionGroups", group["id"]) } } })["data"]
end

unless sub
  puts "Rien d'autre à lire tant que l'abonnement n'existe pas."
  exit
end

# La note de revue suit ce que l'abonnement vend (depuis le 22/11/2026, l'app
# entière : plus de pub, hard paywall).
if step("  note de revue à jour", sub.dig("attributes", "reviewNote") != REVIEW_NOTE)
  call(:patch, "subscriptions/#{sub['id']}",
       { data: { type: "subscriptions", id: sub["id"], attributes: { reviewNote: REVIEW_NOTE } } })
end

# 3. Nom et description par langue
have = all("subscriptions/#{sub['id']}/subscriptionLocalizations?limit=200")
       .to_h { |l| [l.dig("attributes", "locale"), l] }
LOCALES.each do |locale, (name, description)|
  abort("#{locale} : nom trop long") if name.length > 30
  abort("#{locale} : description trop longue (#{description.length})") if description.length > 45
  if (current = have[locale])
    stale = current.dig("attributes", "name") != name || current.dig("attributes", "description") != description
    # Une fiche déjà approuvée (ACTIVE) ne s'édite pas par l'API (409
    # ENTITY_ERROR.ATTRIBUTE.INVALID.UNMODIFIABLE, vu le 22/11/2026) : c'est
    # dans le site, page de l'abonnement, que le texte se change.
    if stale && %w[ACTIVE APPROVED].include?(current.dig("attributes", "state"))
      puts "!   fiche #{locale} approuvée, texte périmé : à changer dans le site → « #{description} »"
      next
    end
    next unless step("  fiche de l'abonnement en #{locale} à jour", stale)
    call(:patch, "subscriptionLocalizations/#{current['id']}",
         { data: { type: "subscriptionLocalizations", id: current["id"],
                   attributes: { name: name, description: description } } })
    next
  end
  next unless step("  fiche de l'abonnement en #{locale}", true)
  call(:post, "subscriptionLocalizations",
       { data: { type: "subscriptionLocalizations",
                 attributes: { name: name, description: description, locale: locale },
                 relationships: { subscription: rel("subscriptions", sub["id"]) } } })
end

# 4. La disponibilité, AVANT les prix : un prix posé dans un pays où l'abonnement
# n'est pas encore disponible est refusé (409 UNSUPPORTED_TERRITORY, vu le
# 14/11/2026 sur le tout premier prix, en France).
available = begin
  call(:get, "subscriptions/#{sub['id']}/subscriptionAvailability")["data"]
rescue SystemExit
  nil
end
if step("disponible dans tous les pays", available.nil?)
  territories = all("territories?limit=200").map { |t| { type: "territories", id: t["id"] } }
  available = call(:post, "subscriptionAvailabilities",
       { data: { type: "subscriptionAvailabilities",
                 attributes: { availableInNewTerritories: true },
                 relationships: { subscription: rel("subscriptions", sub["id"]),
                                  availableTerritories: { data: territories } } } })["data"]
end

# 5. Le prix
#
# Le prix VISÉ est celui de `PRICE` (base France) et de `FORCED` ; chaque pays
# compare le palier qu'il a (en cours ou déjà programmé) au palier visé, par
# identifiant de palier, jamais par chaîne. Un pays qui n'a pas le bon palier
# en reçoit un nouveau. Quand le pays avait déjà un prix, le nouveau est posé
# avec `preserveCurrentPrice: true` : les abonnés en cours gardent leur prix
# (décision de Sharik, 22/11/2026, passage de 1,99 à 4,99), seuls les nouveaux
# paient le nouveau.
def point_at(sub_id, territory, price)
  points = all("subscriptions/#{sub_id}/pricePoints?filter[territory]=#{territory}&limit=8000")
  # En nombre, jamais en chaîne : l'API rend « 1.99 » ici et « 1.990 » ailleurs.
  points.find { |p| (p.dig("attributes", "customerPrice").to_f - price).abs < 0.001 } or
    abort("Pas de palier à #{price} pour #{territory}")
end

def set_price(sub_id, point_id, preserve)
  attributes = { preserveCurrentPrice: preserve }
  attributes[:startDate] = START if preserve && START
  call(:post, "subscriptionPrices",
       { data: { type: "subscriptionPrices",
                 attributes: attributes,
                 relationships: { subscription: rel("subscriptions", sub_id),
                                  subscriptionPricePoint: rel("subscriptionPricePoints", point_id) } } })
end

# territoire → paliers qu'il porte (le courant et ceux déjà programmés).
held = Hash.new { |h, k| h[k] = [] }
all("subscriptions/#{sub['id']}/prices?include=territory&limit=200").each do |p|
  territory = p.dig("relationships", "territory", "data", "id") or next
  held[territory] << p.dig("relationships", "subscriptionPricePoint", "data", "id")
end

base = point_at(sub["id"], BASE_TERRITORY, PRICE)
# Le palier visé, pays par pays : la France, ce qu'Apple en déduit ailleurs,
# et les pays imposés.
target = { BASE_TERRITORY => base["id"] }
all("subscriptionPricePoints/#{base['id']}/equalizations?include=territory&limit=8000").each do |p|
  territory = p.dig("relationships", "territory", "data", "id")
  next if territory.nil? || territory == BASE_TERRITORY || FORCED.key?(territory)
  target[territory] = p["id"]
end
FORCED.each { |territory, price| target[territory] = point_at(sub["id"], territory, price)["id"] }

todo = target.reject { |territory, point| held[territory].include?(point) }
changes = todo.count { |territory, _| !held[territory].empty? }
label = "prix #{PRICE} (#{BASE_TERRITORY}) + équivalents, #{FORCED.map { |t, v| "#{v} #{t}" }.join(', ')} : " \
        "#{todo.size} pays à poser (#{changes} changements, prix des abonnés actuels préservé)"
if changes.positive? && APPLY && START.nil?
  abort("#{changes} pays ont déjà un prix : un changement se programme à une date. " \
        "Relancer avec --start AAAA-MM-JJ (par exemple demain).")
end
if step(label, !todo.empty?)
  todo.each_with_index do |(territory, point), i|
    set_price(sub["id"], point, !held[territory].empty?)
    print "\r  #{i + 1}/#{todo.size}"
  end
  puts
end

# 5 bis. L'offre d'introduction : trois jours gratuits, une fois par compte
# Apple, dans chaque pays où l'abonnement est en vente. L'app la lit dans
# `product.subscription.introductoryOffer` et ne l'affiche que si le lecteur y a
# droit (`isEligibleForIntroOffer`). Une offre par pays : l'API la rattache à
# un territoire.
offered = all("subscriptions/#{sub['id']}/introductoryOffers?include=territory&limit=200")
          .map { |o| o.dig("relationships", "territory", "data", "id") }.compact
territories = available ? all("subscriptionAvailabilities/#{available['id']}/availableTerritories?limit=200").map { |t| t["id"] } : []
missing = territories - offered
if step("offre d'introduction #{TRIAL} gratuite : #{missing.size} pays sur #{territories.size}", !missing.empty?)
  missing.each_with_index do |territory, i|
    call(:post, "subscriptionIntroductoryOffers",
         { data: { type: "subscriptionIntroductoryOffers",
                   attributes: { duration: TRIAL, offerMode: "FREE_TRIAL", numberOfPeriods: 1 },
                   relationships: { subscription: rel("subscriptions", sub["id"]),
                                    territory: rel("territories", territory) } } })
    print "\r  #{i + 1}/#{missing.size}"
  end
  puts
end

# 6. La capture pour la revue
if SHOT
  abort("#{SHOT} introuvable") unless File.exist?(SHOT)
  existing = begin
    call(:get, "subscriptions/#{sub['id']}/appStoreReviewScreenshot")["data"]
  rescue SystemExit
    nil
  end
  if step("capture du paywall pour la revue", existing.nil?)
    bytes = File.binread(SHOT)
    shot = call(:post, "subscriptionAppStoreReviewScreenshots",
                { data: { type: "subscriptionAppStoreReviewScreenshots",
                          attributes: { fileName: File.basename(SHOT), fileSize: bytes.bytesize },
                          relationships: { subscription: rel("subscriptions", sub["id"]) } } })["data"]
    shot.dig("attributes", "uploadOperations").each do |op|
      uri = URI(op["url"])
      req = Net::HTTP::Put.new(uri)
      op["requestHeaders"].each { |h| req[h["name"]] = h["value"] }
      req.body = bytes.byteslice(op["offset"], op["length"])
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
      abort("Envoi de la capture : HTTP #{res.code}") unless res.code.to_i.between?(200, 299)
    end
    call(:patch, "subscriptionAppStoreReviewScreenshots/#{shot['id']}",
         { data: { type: "subscriptionAppStoreReviewScreenshots", id: shot["id"],
                   attributes: { uploaded: true, sourceFileChecksum: Digest::MD5.hexdigest(bytes) } } })
  end
end

state = call(:get, "subscriptions/#{sub['id']}")["data"]["attributes"]["state"]
puts "état de l'abonnement : #{state}"
puts "MISSING_METADATA = il manque encore la capture de revue (--screenshot)." if state == "MISSING_METADATA"
puts "READY_TO_SUBMIT = à cocher sur la page de la prochaine version, avant l'envoi en revue." if state == "READY_TO_SUBMIT"
