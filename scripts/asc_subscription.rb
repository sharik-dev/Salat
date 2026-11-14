# Déclare l'abonnement Salat Premium sur App Store Connect.
#
#   ruby scripts/asc_subscription.rb            # lit et dit ce qui manque, n'écrit rien
#   ruby scripts/asc_subscription.rb --apply    # crée ce qui manque
#   ruby scripts/asc_subscription.rb --apply --screenshot chemin/paywall.png
#
# Ce que ça pose, dans l'ordre, et chaque étape regarde d'abord si c'est déjà
# fait (le script se relance sans rien dupliquer) :
#
#   1. le groupe d'abonnements « Salat Premium » et son nom par langue ;
#   2. l'abonnement mensuel `com.salat.premium.monthly` : l'identifiant est
#      celui de `Store.productID` dans l'app, à la lettre près ;
#   3. son nom et sa description par langue (30 et 45 caractères au plus) ;
#   4. son prix : 1,99 € en France, qui sert de base, le palier équivalent
#      qu'Apple en déduit partout ailleurs, et 1,99 $ imposé aux États-Unis ;
#   5. sa disponibilité dans tous les pays, nouveaux pays compris ;
#   6. avec `--screenshot`, la capture du paywall que la revue exige.
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

GROUP_NAME   = "Salat Premium"
PRODUCT_NAME = "Salat Premium mensuel"
PERIOD       = "ONE_MONTH"
BASE_TERRITORY = "FRA"
PRICE          = 1.99
# Les pays où le palier est imposé au lieu d'être déduit de la France.
FORCED = { "USA" => 1.99 }

# Nom (30 max) et description (45 max) de l'abonnement, par langue de la fiche.
LOCALES = {
  "en-US" => ["Salat Premium", "Home Screen widget, and no ads"],
  "fr-FR" => ["Salat Premium", "Widget d'écran d'accueil, sans pub"],
  "ar-SA" => ["Salat Premium", "أداة الشاشة الرئيسية، بلا إعلانات"]
}

REVIEW_NOTE = "Salat Premium unlocks the Home Screen widget (prayer steps or the " \
              "user's own Qur'an verses) and removes ads. The paywall opens from " \
              "Settings > Salat Premium, or Memorise > Home screen widget > Unlock."

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

# 3. Nom et description par langue
have = all("subscriptions/#{sub['id']}/subscriptionLocalizations?limit=200")
       .map { |l| l.dig("attributes", "locale") }
LOCALES.each do |locale, (name, description)|
  abort("#{locale} : nom trop long") if name.length > 30
  abort("#{locale} : description trop longue (#{description.length})") if description.length > 45
  next unless step("  fiche de l'abonnement en #{locale}", !have.include?(locale))
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
  call(:post, "subscriptionAvailabilities",
       { data: { type: "subscriptionAvailabilities",
                 attributes: { availableInNewTerritories: true },
                 relationships: { subscription: rel("subscriptions", sub["id"]),
                                  availableTerritories: { data: territories } } } })
end

# 5. Le prix
def point_at(sub_id, territory, price)
  points = all("subscriptions/#{sub_id}/pricePoints?filter[territory]=#{territory}&limit=8000")
  # En nombre, jamais en chaîne : l'API rend « 1.99 » ici et « 1.990 » ailleurs.
  points.find { |p| (p.dig("attributes", "customerPrice").to_f - price).abs < 0.001 } or
    abort("Pas de palier à #{price} pour #{territory}")
end

def set_price(sub_id, point_id)
  call(:post, "subscriptionPrices",
       { data: { type: "subscriptionPrices",
                 attributes: { preserveCurrentPrice: false },
                 relationships: { subscription: rel("subscriptions", sub_id),
                                  subscriptionPricePoint: rel("subscriptionPricePoints", point_id) } } })
end

priced = all("subscriptions/#{sub['id']}/prices?include=territory&limit=200")
         .map { |p| p.dig("relationships", "territory", "data", "id") }.compact
base = point_at(sub["id"], BASE_TERRITORY, PRICE)

if step("prix de base : #{PRICE} en #{BASE_TERRITORY}", !priced.include?(BASE_TERRITORY))
  set_price(sub["id"], base["id"])
end

# Le palier équivalent dans chaque autre pays, tel qu'Apple le déduit du prix
# de base. Un par pays, donc autant d'appels : c'est long une fois, et une fois.
equal = all("subscriptionPricePoints/#{base['id']}/equalizations?include=territory&limit=8000")
todo = equal.reject do |p|
  territory = p.dig("relationships", "territory", "data", "id")
  territory.nil? || territory == BASE_TERRITORY || FORCED.key?(territory) || priced.include?(territory)
end
if step("prix déduits dans #{todo.size} autres pays", !todo.empty?)
  todo.each_with_index do |p, i|
    set_price(sub["id"], p["id"])
    print "\r  #{i + 1}/#{todo.size}"
  end
  puts
end

FORCED.each do |territory, price|
  next unless step("prix imposé : #{price} en #{territory}", !priced.include?(territory))
  set_price(sub["id"], point_at(sub["id"], territory, price)["id"])
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
