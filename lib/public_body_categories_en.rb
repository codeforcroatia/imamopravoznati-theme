# The PublicBodyCategories structure works like this:
# [
#   "Main category name",
#       [ "tag_to_use_as_category", "Sub category title", "sentence that can describes things in this subcategory" ],
#       [ "another_tag", "Second sub category title", "another descriptive sentence for things in this subcategory"],
#   "Another main category name",
#       [ "another_tag_2", "Another sub category title", "another descriptive sentence"]
# ])


PublicBodyCategories.add(:en, [
        _"Founder",
            [ "rh", "Republic of Croatia", "Founder is Republic of Croatia" ],
            [ "samouprava", "Local and regional administrative divisions", "Founder is Local and Regional administrative division" ],
            [ "javnopravno-tijelo", "Administrative bodies", "Founder is administrative body or body with delegated public powers" ],
            [ "pravna-osoba", "Natural or legal person", "Founder is natural or legal person" ],
        _("Legal status"),
            [ "drzavna-tijela", "State bodies", "it is a state body" ],
            [ "drzavna-uprava", "State administration bodies", "it is a state administration body" ],
            [ "jedinice-samouprave", "Local and regional administrative divisions", "it is a local and regional administrative division" ],
            [ "sudovi", "Courts and judiciary bodies", "it is a court and judiciary body" ],
            [ "agencije", "Agencies, institutes, funds, centers", "it is an agency, institute, fund, or center" ],
            [ "javne-ustanove", "Public institutions", "it is a public institution" ],
            [ "trgovacka-drustva", "Companies", "it is a company" ],
            [ "udruge", "Non-governmental organizations", "it is a non-governmental organization or civil society organization" ],
            [ "ostale-pravne-osobe", "Other natural and legal persons", "it is other natural or legal person with delegated public powers" ],
        "Topics",
            [ "javna-uprava-politicki", "Public administration and political system", "in a public administration and political system" ],
            [ "obrana-sigurnost", "Defense and national security", "in a defense and national security" ],
            [ "javni-red", "Law enforcement and public safety", "in a law enforcement and public safety" ],
            [ "pravosudje", "Court system", "in a court system" ],
            [ "javne-financije", "Public finances", "in a public finances" ],
            [ "vanjski-poslovi", "Foreign affairs", "in a foreign affairs" ],
            [ "gospodarstvo", "Economy", "in the economy" ],
            [ "promet-komunikacije", "Traffic and communications", "in a traffic or communications" ],
            [ "obrazovanje", "Nurture, education, sports and science", "in a nurture, education, sports or science" ],
            [ "kultura-umjetnost", "Culture and art", "in a culture and art" ],
            [ "zaposljavanje", "Employment, labour and labor relations", "in an employment, labour or labor relations" ],
            [ "socijalna-zastita", "Social care", "in a social care" ],
            [ "zdravstvo", "Health system", "in a health system" ],
            [ "poljoprivreda", "Agriculture, forestry and veterinary", "in an agriculture, forestry or veterinary" ],
            [ "komunalne-usluge", "Municipal services and water management", "in a municipal services or water management" ],
            [ "okolis", "Environmental protection and sustainable development", "in an environmental protection or sustainable development" ],
            [ "regionalni-razvoj", "Regional development", "in a regional development" ],
            [ "turizam", "Tourism", "in a tourism" ],
            [ "statistika-informatika-dokumentacija", "Statistics and information documentation", "in a statistics or information documentation" ],
            [ "hidrometeorologija", "Hydrometeorology", "in a hydrometeorology" ],
            [ "ostalo", "Other - unclassified", "in the other - unclassified topic" ],
        "Other",
            [ "pravne-osobe-proracun", "Legal entity", "legal entity financed predominantly or entirely from the state budget/local/regional budget or from public funds" ],
            [ "defunct", "Defunct", "a body that is now defunct" ],
            [ "internal", "Internal structure", "an internal structure unit" ],
            [ "pending", "Unassigned", "unassigned and waiting to be classified in the public body register" ],
            [ "todo", "To-do", "needs administrator supervision" ],
            [ "stecaj", "Bankruptcy", "in bankruptcy proceedings" ]
    ]
)