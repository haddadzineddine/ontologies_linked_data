require_relative "../test_case"

class TestHTTPCache < LinkedData::TestCase

  def self.before_suite
    self.new("before_suite").delete_ontologies_and_submissions
    @@ontology, @@cls = self.new("before_suite")._ontology_and_class
  end

  def self.after_suite
    self.new("after_suite").delete_ontologies_and_submissions
    LinkedData::HTTPCache.invalidate_all
  end

  def _ontology_and_class
    results = create_ontologies_and_submissions(ont_count: 1, submission_count: 1, process_submission: true)
    ontology = results[2].first
    cls = LinkedData::Models::Class.where.include(:prefLabel).in(ontology.latest_submission).page(1, 1).first
    return ontology, cls
  end

  def setup
    LinkedData::HTTPCache.invalidate_all
  end

  def teardown
    LinkedData::HTTPCache.invalidate_all
  end

  def test_last_modified_valid
    @@ontology.cache_write
    assert @@ontology.last_modified
    assert @@ontology.last_modified_valid?(@@ontology.last_modified)
  end

  def test_cache_invalidate
    @@ontology.cache_write
    assert @@ontology.last_modified
    @@ontology.cache_invalidate
    assert_nil @@ontology.last_modified
  end

  def test_cache_segment_invalidate
    classes = LinkedData::Models::Class.where.include(:prefLabel).in(@@ontology.latest_submission).page(1, 100).to_a
    classes.each {|c| c.cache_write}
    last_modified_values = classes.map {|c| c.last_modified}
    assert last_modified_values.length == classes.length
    classes.first.cache_segment_invalidate
    last_modified_values = (classes.map {|c| c.last_modified}).compact
    assert last_modified_values.empty?
  end

  def test_cache_segment_invalidate_when_member_invalidates
    classes = LinkedData::Models::Class.where.include(:prefLabel).in(@@ontology.latest_submission).page(1, 100).to_a
    classes.each {|c| c.cache_write}
    last_modified_values = classes.map {|c| c.last_modified}
    assert last_modified_values.length == classes.length
    classes.first.cache_invalidate
    last_modified_values = (classes.map {|c| c.last_modified}).compact
    assert last_modified_values.empty?
  end

  def test_ld_save_invalidates
    results = create_ontologies_and_submissions(ont_count: 1, submission_count: 1, process_submission: false)
    ontology = results[2].first
    last_modified = ontology.cache_write
    ontology.bring_remaining
    ontology.name = "New name for save"
    sleep(1)
    ontology.save
    assert Time.httpdate(ontology.last_modified) > Time.httpdate(last_modified)
  end

  def test_ld_delete_invalidates
    results = create_ontologies_and_submissions(ont_count: 1, submission_count: 1, process_submission: false)
    ontology = results[2].first
    last_modified = ontology.cache_write
    ontology.bring_remaining
    sleep(1)
    ontology.delete
    refute ontology.last_modified
  end

  def test_segment_last_modified
    @@cls.cache_write
    assert @@cls.segment_last_modified
  end

  def test_cache_segment
    assert @@cls.cache_segment.eql?(":TEST-ONT-0:class")
  end

  def test_collection_last_modified_valid
    assert_nil LinkedData::Models::Ontology.collection_last_modified
    LinkedData::Models::Ontology.cache_collection_write
    assert LinkedData::Models::Ontology.collection_last_modified
    assert LinkedData::Models::Ontology.collection_last_modified_valid?(LinkedData::Models::Ontology.collection_last_modified)
  end

  def test_cache_collection_invalidate
    assert_nil LinkedData::Models::Ontology.collection_last_modified
    LinkedData::Models::Ontology.cache_collection_write
    assert LinkedData::Models::Ontology.collection_last_modified
    LinkedData::Models::Ontology.cache_collection_invalidate
    assert_nil LinkedData::Models::Ontology.collection_last_modified
  end

  def test_cache_invalidate_all
    LinkedData::Models::Ontology.cache_collection_write
    LinkedData::Models::Class.cache_collection_write
    assert LinkedData::Models::Ontology.collection_last_modified
    assert LinkedData::Models::Class.collection_last_modified
    classes = LinkedData::Models::Class.where.include(:prefLabel).in(@@ontology.latest_submission).page(1, 100).to_a
    classes.each {|c| c.cache_write}
    last_modified_values = classes.map {|c| c.last_modified}
    assert last_modified_values.length == classes.length
    LinkedData::HTTPCache.invalidate_all
    assert_nil LinkedData::Models::Ontology.collection_last_modified
    assert_nil LinkedData::Models::Class.collection_last_modified
    last_modified_values = (classes.map {|c| c.last_modified}).compact
    assert last_modified_values.empty?
  end

end