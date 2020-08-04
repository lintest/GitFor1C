#include "GitManager.h"
#include "AddInBase.h"
#include "json_ext.h"

#include <stdexcept>
#include <iostream>
#include <cstring>
#include <string>
#include <thread>

#ifdef _WINDOWS
#include <windows.h>
#include <conio.h>
#pragma comment(lib, "git2")
#pragma comment(lib, "crypt32")
#pragma comment(lib, "rpcrt4")
#pragma comment(lib, "winhttp")
#endif _WINDOWS

#define S(wstr) WC2MB(wstr).c_str()

#define CHECK_REPO() {if (m_repo == nullptr) return ::error("Repo is null");}

#define ASSERT(t) {if (t < 0) return ::error();}

#define AUTO_GIT(N, T, F)              \
class N {                              \
private:                               \
	T* h = nullptr;                    \
public:                                \
	N() {}                             \
	N(T* h) { this->h = h; }           \
	~N() { if (h) (F(h)); }            \
	operator T*() const { return h; }  \
	T** operator &() { return &h; }    \
	T* operator->() { return h; }      \
	operator bool() { return h; }      \
}                                      \
;


AUTO_GIT(GIT_status_list, git_status_list, git_status_list_free)
AUTO_GIT(GIT_signature, git_signature, git_signature_free)
AUTO_GIT(GIT_revwalk, git_revwalk, git_revwalk_free)
AUTO_GIT(GIT_commit, git_commit, git_commit_free)
AUTO_GIT(GIT_object, git_object, git_object_free)
AUTO_GIT(GIT_index, git_index, git_index_free)
AUTO_GIT(GIT_blob, git_blob, git_blob_free)
AUTO_GIT(GIT_diff, git_diff, git_diff_free)
AUTO_GIT(GIT_tree, git_tree, git_tree_free)

GitManager::GitManager(AddInNative* addin)
{
	m_addin = addin;
	git_libgit2_init();
}

GitManager::~GitManager()
{
	if (m_repo) git_repository_free(m_repo);
	if (m_committer) delete m_committer;
	if (m_author) delete m_author;
	git_libgit2_shutdown();
}

static std::wstring success(const nlohmann::json& result)
{
	nlohmann::json json;
	json["result"] = result;
	json["success"] = true;
	return MB2WC(json.dump());
}

static std::wstring error()
{
	const git_error* e = git_error_last();
	nlohmann::json json, j;
	j["code"] = e->klass;
	j["message"] = e->message;
	json["error"] = j;
	json["success"] = false;
	return MB2WC(json.dump());
}

static std::wstring error(const std::string& message)
{
	nlohmann::json json, j;
	j["message"] = message;
	json["error"] = j;
	json["success"] = false;
	return MB2WC(json.dump());
}

std::wstring GitManager::init(const std::wstring& path, bool is_bare)
{
	if (m_repo) git_repository_free(m_repo);
	ASSERT(git_repository_init(&m_repo, S(path), is_bare));
	return {};
}

std::wstring GitManager::clone(const std::wstring& url, const std::wstring& path)
{
	if (m_repo) git_repository_free(m_repo);
	ASSERT(git_clone(&m_repo, S(url), S(path), nullptr));
	return {};
}

std::wstring GitManager::open(const std::wstring& path)
{
	if (m_repo) git_repository_free(m_repo);
	ASSERT(git_repository_open(&m_repo, S(path)));
	return {};
}

std::wstring GitManager::find(const std::wstring& path)
{
	git_buf root = { 0 };
	ASSERT(git_repository_discover(&root, S(path), 0, nullptr));
	nlohmann::json j;
	j["path"] = root.ptr;
	return success(j);
}

static std::string status2str(git_status_t status) {
	switch (status) {
	case GIT_STATUS_CURRENT: return "CURRENT";
	case GIT_STATUS_INDEX_NEW: return "INDEX_NEW";
	case GIT_STATUS_INDEX_MODIFIED: return "INDEX_MODIFIED";
	case GIT_STATUS_INDEX_DELETED: return "INDEX_DELETED";
	case GIT_STATUS_INDEX_RENAMED: return "INDEX_RENAMED";
	case GIT_STATUS_INDEX_TYPECHANGE: return "INDEX_TYPECHANGE";
	case GIT_STATUS_WT_NEW: return "WT_NEW";
	case GIT_STATUS_WT_MODIFIED: return "WT_MODIFIED";
	case GIT_STATUS_WT_DELETED: return "WT_DELETED";
	case GIT_STATUS_WT_TYPECHANGE: return "WT_TYPECHANGE";
	case GIT_STATUS_WT_RENAMED: return "WT_RENAMED";
	case GIT_STATUS_WT_UNREADABLE: return "WT_UNREADABLE";
	case GIT_STATUS_IGNORED: return "IGNORED";
	case GIT_STATUS_CONFLICTED: return "CONFLICTED";
	default: return {};
	}
}

static std::string delta2str(git_delta_t status) {
	switch (status) {
	case GIT_DELTA_UNMODIFIED: return "UNMODIFIED";
	case GIT_DELTA_ADDED: return "ADDED";
	case GIT_DELTA_DELETED: return "DELETED";
	case GIT_DELTA_MODIFIED: return "MODIFIED";
	case GIT_DELTA_RENAMED: return "RENAMED";
	case GIT_DELTA_COPIED: return "COPIED";
	case GIT_DELTA_IGNORED: return "IGNORED";
	case GIT_DELTA_UNTRACKED: return "UNTRACKED";
	case GIT_DELTA_TYPECHANGE: return "TYPECHANGE";
	case GIT_DELTA_UNREADABLE: return "UNREADABLE";
	case GIT_DELTA_CONFLICTED: return "CONFLICTED";
	default:  return "UNMODIFIED";
	}
}

static nlohmann::json flags2json(unsigned int status_flags) {
	nlohmann::json json;
	for (unsigned int i = 0; i < 16; i++) {
		git_status_t status = git_status_t(1u << i);
		if (status & status_flags) {
			json.push_back(status2str(status));
		}
	}
	return json;
}

static std::string oid2str(const git_oid* id)
{
	if (git_oid_is_zero(id)) return {};
	const size_t size = GIT_OID_HEXSZ + 1;
	char buf[size];
	git_oid_tostr(buf, size, id);
	return buf;
}

int status_cb(const char* path, unsigned int status_flags, void* payload)
{
	nlohmann::json* json = (nlohmann::json*)payload;
	nlohmann::json j;
	j["filepath"] = path;
	j["statuses"] = flags2json(status_flags);
	json->push_back(j);
	return 0;
}

nlohmann::json delta2json(git_diff_delta* delta)
{
	nlohmann::json j;
	j["status"] = delta2str(delta->status);
	j["old_id"] = oid2str(&delta->old_file.id);
	j["old_name"] = delta->old_file.path;
	j["old_size"] = delta->old_file.size;
	j["new_id"] = oid2str(&delta->new_file.id);
	j["new_name"] = delta->new_file.path;
	j["new_size"] = delta->new_file.size;
	return j;
}

std::wstring GitManager::status()
{
	CHECK_REPO();

	nlohmann::json json, jIndex, jWork;
	GIT_status_list statuses = NULL;
	git_status_options opts = GIT_STATUS_OPTIONS_INIT;
	opts.flags = GIT_STATUS_OPT_DEFAULTS;
	ASSERT(git_status_list_new(&statuses, m_repo, &opts));
	size_t count = git_status_list_entrycount(statuses);
	for (size_t i = 0; i < count; ++i) {
		const git_status_entry* entry = git_status_byindex(statuses, i);
		if (entry->head_to_index) jIndex.push_back(delta2json(entry->head_to_index));
		if (entry->index_to_workdir) jWork.push_back(delta2json(entry->index_to_workdir));
	}
	if (jIndex.is_array()) json["index"] = jIndex;
	if (jWork.is_array()) json["work"] = jWork;
	return success(json);
}

bool GitManager::setAuthor(const std::wstring& name, const std::wstring& email)
{
	if (m_author) delete m_author;
	m_author = new Signature(name, email);
	return true;
}

bool GitManager::setCommitter(const std::wstring& name, const std::wstring& email)
{
	if (m_committer) delete m_committer;
	m_committer = new Signature(name, email);
	return true;
}

std::wstring GitManager::signature()
{
	CHECK_REPO();
	git_signature* sig = nullptr;
	ASSERT(git_signature_default(&sig, m_repo));

	nlohmann::json j;
	j["name"] = sig->name;
	j["email"] = sig->email;
	return success(j);
}

std::wstring GitManager::commit(const std::wstring& msg)
{
	CHECK_REPO();
	GIT_signature sig;
	GIT_signature author;
	GIT_signature committer;
	if (m_author) m_author->now(&author);
	if (m_committer) m_committer->now(&committer);
	if (m_author == nullptr || m_committer == nullptr) {
		git_signature_default(&sig, m_repo);
	}

	int ok = 0;
	GIT_index index;
	GIT_tree tree;
	git_oid tree_id, commit_id;
	git_object* head_commit = nullptr;
	git_revparse_single(&head_commit, m_repo, "HEAD^{commit}");
	GIT_commit commit = (git_commit*)head_commit;
	size_t head_count = head_commit ? 1 : 0;
	ASSERT(git_repository_index(&index, m_repo));
	ASSERT(git_index_write_tree(&tree_id, index));
	ASSERT(git_tree_lookup(&tree, m_repo, &tree_id));

	ASSERT(git_commit_create_v(
		&commit_id,
		m_repo,
		"HEAD",
		author ? author : sig,
		committer ? committer : sig,
		NULL, 
		S(msg),
		tree,
		head_count,
		head_commit
	));
	return {};
}

std::wstring GitManager::add(const std::wstring& filepath)
{
	CHECK_REPO();
	GIT_index index;
	ASSERT(git_repository_index(&index, m_repo));
	ASSERT(git_index_add_bypath(index, S(filepath)));
	ASSERT(git_index_write(index));
	return {};
}

std::wstring GitManager::remove(const std::wstring& filepath)
{
	CHECK_REPO();
	GIT_index index;
	ASSERT(git_repository_index(&index, m_repo));
	ASSERT(git_index_remove_bypath(index, S(filepath)));
	ASSERT(git_index_write(index));
	return {};
}

std::wstring GitManager::info(const std::wstring& spec)
{
	CHECK_REPO();
	git_object* head_commit;
	ASSERT(git_revparse_single(&head_commit, m_repo, S(spec)));
	GIT_commit commit = (git_commit*)head_commit;
	const git_oid* tree_id = git_commit_tree_id(commit);
	const git_signature* author = git_commit_author(commit);
	nlohmann::json j;
	j["id"] = oid2str(tree_id);
	j["author.name"] = author->name;
	j["author.email"] = author->email;
	j["message"] = git_commit_message(commit);
	return success(j);
}

std::wstring GitManager::history(const std::wstring& spec)
{
	CHECK_REPO();

	git_oid oid;
	GIT_revwalk walker;
	git_revwalk_new(&walker, m_repo);
	git_revwalk_sorting(walker, GIT_SORT_TIME);
	git_revwalk_push_head(walker);

	nlohmann::json json;
	while (git_revwalk_next(&oid, walker) == 0) {
		GIT_commit commit;
		ASSERT(git_commit_lookup(&commit, m_repo, &oid));
		const git_oid* tree_id = git_commit_tree_id(commit);
		const git_signature* author = git_commit_author(commit);
		const git_signature* committer = git_commit_committer(commit);
		nlohmann::json j;
		j["id"] = oid2str(tree_id);
		j["authorName"] = author->name;
		j["authorEmail"] = author->email;
		j["committerName"] = committer->name;
		j["committerEmail"] = committer->email;
		j["time"] = git_commit_time(commit);
		j["message"] = git_commit_message(commit);
		json.push_back(j);
	}
	return success(json);
}

std::string type2str(git_object_t type) {
	switch (type) {
	case GIT_OBJECT_TREE: return "tree";
	case GIT_OBJECT_BLOB: return "blob";
	default: return {};
	}
}

int tree_walk_cb(const char* root, const git_tree_entry* entry, void* payload)
{
	nlohmann::json* json = (nlohmann::json*)payload;
	nlohmann::json j;
	git_object_t type = git_tree_entry_type(entry);
	j["id"] = oid2str(git_tree_entry_id(entry));
	j["name"] = git_tree_entry_name(entry);
	j["type"] = type2str(type);
	j["root"] = root;
	json->push_back(j);
	return 0;
}

std::wstring GitManager::tree(const std::wstring& msg)
{
	CHECK_REPO();

	git_object* obj = NULL;
	ASSERT(git_revparse_single(&obj, m_repo, "HEAD^{tree}"));
	GIT_tree tree = (git_tree*)obj;

	nlohmann::json json;
	ASSERT(git_tree_walk(tree, GIT_TREEWALK_PRE, tree_walk_cb, &json));
	return success(json);
}


int diff_file_cb(const git_diff_delta* delta, float progress, void* payload)
{
	nlohmann::json* json = (nlohmann::json*)payload;
	nlohmann::json j;
	j["status"] = delta2str(delta->status);
	j["flags"] = flags2json(delta->flags);
	j["old_id"] = oid2str(&delta->old_file.id);
	j["old_name"] = delta->old_file.path;
	j["new_id"] = oid2str(&delta->new_file.id);
	j["new_name"] = delta->new_file.path;
	j["similarity"] = delta->similarity;
	json->push_back(j);
	return 0;
}

std::wstring GitManager::diff(const std::wstring& s1, const std::wstring& s2)
{
	GIT_diff diff = NULL;
	if ((s1 == L"INDEX" && s2 == L"WORK") || (s2 == L"INDEX" && s1 == L"WORK")) {
		ASSERT(git_diff_index_to_workdir(&diff, m_repo, NULL, NULL));
	}
	else if ((s1 == L"HEAD" && s2 == L"INDEX") || (s2 == L"HEAD" && s1 == L"INDEX")) {
		GIT_object obj = NULL;
		ASSERT(git_revparse_single(&obj, m_repo, "HEAD^{tree}"));
		GIT_tree tree = NULL;
		ASSERT(git_tree_lookup(&tree, m_repo, git_object_id(obj)));
		ASSERT(git_diff_tree_to_index(&diff, m_repo, tree, NULL, NULL));
	}
	else if ((s1 == L"HEAD" && s2 == L"WORK") || (s2 == L"HEAD" && s1 == L"WORK")) {
		GIT_object obj = NULL;
		ASSERT(git_revparse_single(&obj, m_repo, "HEAD^{tree}"));
		GIT_tree tree = NULL;
		ASSERT(git_tree_lookup(&tree, m_repo, git_object_id(obj)));
		ASSERT(git_diff_tree_to_workdir_with_index(&diff, m_repo, tree, NULL));
	}
	nlohmann::json json;
	if (diff) {
		git_diff_find_options opts = GIT_DIFF_FIND_OPTIONS_INIT;
		opts.flags = GIT_DIFF_FIND_RENAMES | GIT_DIFF_FIND_COPIES | GIT_DIFF_FIND_FOR_UNTRACKED;
		ASSERT(git_diff_find_similar(diff, &opts));
		ASSERT(git_diff_foreach(diff, diff_file_cb, NULL, NULL, NULL, &json));
	}
	return success(json);
}

bool GitManager::error(tVariant* pvar)
{
	return ((AddInBase*)m_addin)->VA(pvar) << ::error();
}

bool GitManager::blob(const std::wstring& id, tVariant* pvarRetValue)
{
	git_oid oid;
	int ok = git_oid_fromstr(&oid, S(id));
	if (ok < 0) return error(pvarRetValue);
	GIT_blob blob = NULL;
	ok = git_blob_lookup(&blob, m_repo, &oid);
	if (ok < 0) return error(pvarRetValue);
	git_off_t rawsize = git_blob_rawsize(blob);
	const void* rawcontent = git_blob_rawcontent(blob);
	if (rawsize > 0) {
		m_addin->AllocMemory((void**)&pvarRetValue->pstrVal, rawsize);
		memcpy((void*)pvarRetValue->pstrVal, rawcontent, rawsize);
		TV_VT(pvarRetValue) = VTYPE_BLOB;
		pvarRetValue->strLen = rawsize;
	}
	return true;
}

#include <filesystem>

std::wstring GitManager::fullpath(const std::wstring& path)
{
	std::filesystem::path root = MB2WC(git_repository_path(m_repo));
	return root.parent_path().parent_path().append(path).make_preferred();
}
