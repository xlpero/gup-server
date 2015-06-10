require 'rails_helper'

RSpec.describe V1::PublicationsController, type: :controller do

  describe "index" do
    context "when requiring publications" do
      it "should return a list of objects" do
        create_list(:publication, 10)

        get :index 

        expect(json["publications"]).to_not be nil
        expect(json["publications"]).to be_an(Array)
      end
    end

    context "when requiring drafts" do

      it "should return a list of objects" do
        get :index, :drafts => 'true' 
        expect(json["publications"]).to_not be nil
        expect(json["publications"]).to be_an(Array)
      end
    end
  end

  describe "show" do
    context "for an existing publication" do
      it "should return an object" do
        create(:publication, pubid: 101)

        get :show, :pubid => 101

        expect(json["publication"]).to_not be nil
        expect(json["publication"]).to be_an(Hash)
      end
    end

    context "for a no existing publication" do     
      it "should return an error message" do
        get :show, :pubid => 9999

        expect(json["error"]).to_not be nil
      end  
    end

    context "with person inc department" do
      it "should return a publication" do
        person = create(:person)
        department = create(:department)
        publication = create(:publication, pubid: 101)
        p2p = create(:people2publication, person: person, publication: publication)
        d2p2p = create(:departments2people2publication, people2publication: p2p, department: department)

        get :show, pubid: 101

        expect(json['publication']).to_not be nil
        expect(json['publication']['people']).to_not be nil
        expect(json['publication']['people'][0]['id']).to eq person.id
        expect(json['publication']['people'][0]['departments']).to_not be nil
        expect(json['publication']['people'][0]['departments'][0]['id']).to eq department.id
      end
    end
  end

  describe "create" do 
    context "with datasource parameter" do 
      it "should return created publication" do 
        post :create, :datasource => 'none'
        expect(json["publication"]).to_not be nil
        expect(json["publication"]).to be_an(Hash)
      end
    end
    context "with no parameter" do
      it "should return an error message" do
        post :create
        expect(json["publication"]).to_not be nil
        expect(json["publication"]).to be_an(Hash)      
      end
    end

    #context "with file parameter" do 
    # it "should return the last created publication" do 
    #
    #  post :create, :file => 'xyz'
    #
    #  expect(json["publication"]).to_not be nil
    #  expect(json["publication"]).to be_an(Hash)
    #end
  end  

  describe "update" do
    context "for an existing no deleted and no draft publication" do
      context "with valid parameters" do
        it "should return updated publication" do
          pub = create(:publication, pubid: 45687)

          put :update, pubid: 45687, publication: {title: "New test title"} 

          expect(json["publication"]["title"]).to eq "New test title"
          expect(json["publication"]).to_not be nil
          expect(json["publication"]).to be_an(Hash)
        end
      end
      context "with invalid parameters" do
        it "should return an error message" do
          create(:publication, pubid: 2001)

          put :update, pubid: 2001, publication: {publication_type: 'non-existing-type'}

          expect(json["error"]).to_not be nil
        end
      end
      context "with is_draft=true" do
        it "should return an error message" do
          create(:publication, pubid: 2010)

          put :update, pubid: 2010, publication: {is_draft: true}

          expect(json["error"]).to_not be nil
        end
      end    

    end
    context "for a non existing publication" do
      it "should return an error message" do
        create(:publication, pubid: 2001)

        put :update, pubid: 9999, publication: {title: "New test title"} 

        expect(json["error"]).to_not be nil
      end
    end

    context "with person inc department" do
      it "should return a publication" do
        publication = create(:publication)
        person = create(:person)
        department = create(:department)

        put :update, pubid: publication.pubid, publication: {people: [{id: person.id, departments: [department.as_json]}]}
        publication_new = Publication.where(pubid: publication.pubid).where(is_deleted: false).first
       
        expect(json['error']).to be nil
        expect(json['publication']['people'][0]['id']).to eq person.id
        expect(json['publication']['people'][0]['departments'][0]['id']).to eq department.id
        expect(publication_new.people2publications.size).to eq 1
        expect(publication_new.people2publications.first.departments2people2publications.count).to eq 1
      end

      it "should set the person as affiliated" do
        publication = create(:publication)
        person = create(:person)
        department = create(:department)

        put :update, pubid: publication.pubid, publication: {people: [{id: person.id, departments: [department.as_json]}]}
        expect(Person.find_by_id(person.id).affiliated).to eq true    
      end    
    end

    context "With a list of categories" do
      it "should return a publication" do
        publication = create(:publication, pubid: 2001, is_draft: false)
        
        put :update, pubid: 2001, publication: {category_hsv_local: [1,101]}

        expect(json["error"]).to be nil
        expect(json["publication"]["category_hsv_local"]).to eq [1, 101]
      end
    end
  end

  describe "fetch_import_data" do
    context "for existing pubmed" do
      before :each do
        stub_request(:get, "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=25505574&retmode=xml").
          with(:headers => {'Accept'=>'*/*; q=0.5, application/xml', 'Accept-Encoding'=>'gzip, deflate', 'User-Agent'=>'Ruby'}).
          to_return(:status => 200, :body => File.new("#{Rails.root}/spec/support/adapters/pubmed-25505574.xml"), :headers => {})
      end

      it "should return a publication object" do
        get :fetch_import_data, datasource: 'pubmed', sourceid: '25505574'

        expect(json['publication']).to_not be nil
        expect(json['errors']).to be nil
      end
    end
  end

  describe "destroy" do
    context "for an existing publication" do
      it "should return an empty hash" do
        create(:publication, pubid: 2001, is_draft: true)

        delete :destroy, pubid: 2001 
        expect(json).to be_kind_of(Hash)
        expect(json.empty?).to eq true

      end
    end
    context "for a non existing publication" do
      it "should return an error message" do
        delete :destroy, pubid: 9999
        
        expect(json["error"]).to_not be nil
      end
    end 
    context "for a non draft publication" do
      it "should return error msg" do
        create(:publication, pubid: 2001)

        delete :destroy, pubid: 2001

        expect(json['error']).to_not be nil
      end
    end
  end
end
