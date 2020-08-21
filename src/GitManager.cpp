﻿#include "GitManager.h"
#include "FileFinder.h"
#include "json.hpp"
#include "version.h"

std::vector<std::u16string> GitManager::names = {
	AddComponent(u"GitFor1C", []() { return new GitManager; }),
};

GitManager::GitManager()
{
	git_libgit2_init();

	AddProperty(u"Remotes", u"Remotes", [&](VH var) { var = this->remoteList(); });
	AddProperty(u"Signature", u"Подпись", [&](VH var) { var = this->signature(); });
	AddProperty(u"Version", u"Версия", [&](VH var) { var = std::string(VER_FILE_VERSION_STR); });

	AddFunction(u"Init", u"Init", [&](VH path) { this->result = this->init(path); });
	AddFunction(u"Open", u"Open", [&](VH path) { this->result = this->open(path); });
	AddFunction(u"Find", u"Find", [&](VH path) { this->result = this->find(path); });
	AddFunction(u"Clone", u"Clone", [&](VH url, VH path) { this->result = this->clone(url, path); });
	AddFunction(u"Close", u"Close", [&]() { this->result = this->close(); });
	AddFunction(u"Info", u"Info", [&](VH id) { this->result = this->info(id); });
	AddFunction(u"Diff", u"Diff", [&](VH p1, VH p2) { this->result = this->diff(p1, p2); });
	AddFunction(u"File", u"File", [&](VH path, VH full) { this->result = this->file(path, full); });
	AddFunction(u"Blob", u"Blob", [&](VH id, VH encoding) { this->blob(id, encoding); }, { { 1, 0 } });
	AddFunction(u"Tree", u"Tree", [&](VH id) { this->result = this->tree(id); });
	AddFunction(u"Status", u"Status", [&]() { this->result = this->status(); });
	AddFunction(u"Commit", u"Commit", [&](VH msg) { this->result = this->commit(msg); });
	AddFunction(u"Add", u"Add", [&](VH append, VH remove) { this->result = this->add(append, remove); }, { {1, u""} });
	AddFunction(u"Reset", u"Reset", [&](VH path) { this->result = this->reset(path); });
	AddFunction(u"Remove", u"Remove", [&](VH path) { this->result = this->remove(path); });
	AddFunction(u"Discard", u"Discard", [&](VH path) { this->result = this->discard(path); });
	AddFunction(u"History", u"History", [&](VH path) { this->result = this->history(path); }, { { 0, u"HEAD" } });

	AddProcedure(u"SetAuthor", u"SetAuthor", [&](VH name, VH email) { this->setAuthor(name, email); });
	AddProcedure(u"SetCommitter", u"SetCommitter", [&](VH name, VH email) { this->setCommitter(name, email); });
	AddFunction(u"IsBinary", u"IsBinary", [&](VH blob, VH encoding) { this->result = this->isBinary(blob, encoding); }, { {1, 0} });
	AddFunction(u"GetFullpath", u"GetFullpath", [&](VH path) { this->result = this->getFullpath(path); });
	AddFunction(u"GetEncoding", u"GetEncoding", [&](VH path) { this->result = this->getEncoding(path); });
	AddFunction(u"FindFiles", u"НайтиФайлы", [&](VH path, VH mask, VH text, VH ignore) {
		this->result = FileFinder(text, ignore).find(path, mask);
		}, { {4, true} });
}

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

#define CHECK_REPO() {if (m_repo == nullptr) return ::error(0);}

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
AUTO_GIT(GIT_remote, git_remote, git_remote_free)
AUTO_GIT(GIT_index, git_index, git_index_free)
AUTO_GIT(GIT_blob, git_blob, git_blob_free)
AUTO_GIT(GIT_diff, git_diff, git_diff_free)
AUTO_GIT(GIT_tree, git_tree, git_tree_free)

GitManager::~GitManager()
{
	if (m_repo) git_repository_free(m_repo);
	if (m_committer) delete m_committer;
	if (m_author) delete m_author;
	git_libgit2_shutdown();
}

static std::string success(const nlohmann::json& result)
{
	nlohmann::json json;
	json["result"] = result;
	json["success"] = true;
	return json.dump();
}

static std::string error()
{
	const git_error* e = git_error_last();
	nlohmann::json json, j;
	j["code"] = e->klass;
	j["message"] = e->message;
	json["error"] = j;
	json["success"] = false;
	return json.dump();
}

static std::string error(int code)
{
	nlohmann::json json, j;
	j["code"] = code;
	j["message"] = "Repo is null";
	json["error"] = j;
	json["success"] = false;
	return json.dump();
}

static std::string error(const std::string& msg)
{
	nlohmann::json json, j;
	j["code"] = -1;
	j["message"] = msg;
	json["error"] = j;
	json["success"] = false;
	return json.dump();
}

std::string GitManager::init(const std::string& path)
{
	if (m_repo) git_repository_free(m_repo);
	m_repo = nullptr;
	std::string p = path;
	ASSERT(git_repository_init(&m_repo, p.c_str(), false));
	return success(true);
}

std::string GitManager::clone(const std::string& url, const std::string& path)
{
	if (m_repo) git_repository_free(m_repo);
	m_repo = nullptr;
	ASSERT(git_clone(&m_repo, url.c_str(), path.c_str(), nullptr));
	return success(true);
}

std::string GitManager::open(const std::string& path)
{
	if (m_repo) git_repository_free(m_repo);
	m_repo = nullptr;
	ASSERT(git_repository_open(&m_repo, path.c_str()));
	return success(true);
}

bool GitManager::close()
{
	if (m_repo) git_repository_free(m_repo);
	m_repo = nullptr;
	return true;
}

std::string GitManager::find(const std::string& path)
{
	git_buf buffer = { 0 };
	ASSERT(git_repository_discover(&buffer, path.c_str(), 0, nullptr));
	std::string res = buffer.ptr;
	git_buf_free(&buffer);
	return success(res);
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

static std::string diff2str(git_diff_flag_t flag) {
	switch (flag) {
	case GIT_DIFF_FLAG_BINARY: return "BINARY";
	case GIT_DIFF_FLAG_NOT_BINARY: return "TEXT";
	case GIT_DIFF_FLAG_VALID_ID: return "VALID";
	case GIT_DIFF_FLAG_EXISTS: return "EXISTS";
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

static nlohmann::json diff2json(unsigned int status_flags) {
	nlohmann::json json;
	for (unsigned int i = 0; i < 4; i++) {
		git_diff_flag_t flag = git_diff_flag_t(1u << i);
		if (flag & status_flags) {
			json.push_back(diff2str(flag));
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
	nlohmann::json j;
	j["filepath"] = path;
	j["statuses"] = flags2json(status_flags);
	((nlohmann::json*)payload)->push_back(j);
	return 0;
}

nlohmann::json delta2json(const git_diff_delta* delta, bool index = false)
{
	nlohmann::json j;
	j["flag"] = delta->status;
	j["status"] = delta2str(delta->status);
	j["similarity"] = delta->similarity;
	j["nfiles"] = delta->nfiles;
	j["old_id"] = oid2str(&delta->old_file.id);
	j["old_name"] = delta->old_file.path;
	j["old_size"] = delta->old_file.size;
	j["old_flags"] = delta->old_file.flags;
	if (index) j["new_id"] = oid2str(&delta->new_file.id);
	j["new_name"] = delta->new_file.path;
	j["new_size"] = delta->new_file.size;
	j["new_flags"] = delta->new_file.flags;
	return j;
}

nlohmann::json commit2json(const git_commit* commit)
{
	nlohmann::json j;
	const git_oid* tree_id = git_commit_tree_id(commit);
	const git_signature* author = git_commit_author(commit);
	const git_signature* committer = git_commit_committer(commit);
	j["id"] = oid2str(tree_id);
	j["authorName"] = author->name;
	j["authorEmail"] = author->email;
	j["committerName"] = committer->name;
	j["committerEmail"] = committer->email;
	j["message"] = git_commit_message(commit);
	j["time"] = git_commit_time(commit);
	return j;
}

std::string GitManager::status()
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
		if (entry->head_to_index) jIndex.push_back(delta2json(entry->head_to_index, true));
		if (entry->index_to_workdir) jWork.push_back(delta2json(entry->index_to_workdir));
	}
	if (jIndex.is_array()) json["index"] = jIndex;
	if (jWork.is_array()) json["work"] = jWork;
	return success(json);
}

void GitManager::setAuthor(const std::string& name, const std::string& email)
{
	if (m_author) delete m_author;
	m_author = new Signature(name, email);
}

void GitManager::setCommitter(const std::string& name, const std::string& email)
{
	if (m_committer) delete m_committer;
	m_committer = new Signature(name, email);
}

std::string GitManager::remoteList()
{
	CHECK_REPO();
	git_strarray strarray;
	ASSERT(git_remote_list(&strarray, m_repo));
	nlohmann::json json;
	for (size_t i = 0; i < strarray.count; i++) {
		GIT_remote remote;
		ASSERT(git_remote_lookup(&remote, m_repo, strarray.strings[i]));
		nlohmann::json j;
		j["name"] = strarray.strings[i];
		j["url"] = git_remote_url(remote);
		json.push_back(j);
	}
	git_strarray_free(&strarray);
	return success(json);
}

std::string GitManager::signature()
{
	CHECK_REPO();
	git_signature* sig = nullptr;
	ASSERT(git_signature_default(&sig, m_repo));
	nlohmann::json j;
	j["name"] = sig->name;
	j["email"] = sig->email;
	return success(j);
}

std::string GitManager::commit(const std::string& msg)
{
	CHECK_REPO();
	GIT_signature sig;
	GIT_signature author;
	GIT_signature committer;
	if (m_author) m_author->now(&author);
	if (m_committer) m_committer->now(&committer);
	if (m_author == nullptr || m_committer == nullptr) {
		ASSERT(git_signature_default(&sig, m_repo));
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
		msg.c_str(),
		tree,
		head_count,
		head_commit
	));
	return success(true);
}

static nlohmann::json parse_file_list(std::string filelist)
{
	try {
		return nlohmann::json::parse(filelist);
	}
	catch (nlohmann::json::parse_error e) {
		nlohmann::json json;
		json.push_back(filelist);
		return json;
	}
}

std::string GitManager::add(const std::string& append, const std::string& remove)
{
	CHECK_REPO();
	GIT_index index;
	ASSERT(git_repository_index(&index, m_repo));
	nlohmann::json json_add = parse_file_list(append);
	if (json_add.is_array()) {
		for (auto element : json_add) {
			std::string path = element;
			ASSERT(git_index_add_bypath(index, path.c_str()));
		}
	}
	nlohmann::json json_del = parse_file_list(remove);
	if (json_del.is_array()) {
		for (auto element : json_del) {
			std::string path = element;
			ASSERT(git_index_remove_bypath(index, path.c_str()));
		}
	}
	ASSERT(git_index_write(index));
	return success(true);
}

std::string GitManager::reset(const std::string& filelist)
{
	CHECK_REPO();
	GIT_object obj = NULL;
	ASSERT(git_revparse_single(&obj, m_repo, "HEAD^{commit}"));
	nlohmann::json json = parse_file_list(filelist);
	if (json.is_array()) {
		for (auto element : json) {
			std::string path = element;
			const char* paths[] = { path.c_str() };
			const git_strarray strarray = { (char**)paths, 1 };
			ASSERT(git_reset_default(m_repo, obj, &strarray));
		}
	}
	return success(true);
}

std::string GitManager::discard(const std::string& filelist)
{
	CHECK_REPO();
	git_checkout_options options;
	ASSERT(git_checkout_options_init(&options, GIT_CHECKOUT_OPTIONS_VERSION));
	options.checkout_strategy = GIT_CHECKOUT_FORCE;
	options.paths.count = 1;
	nlohmann::json json = parse_file_list(filelist);
	if (json.is_array()) {
		for (auto element : json) {
			std::string path = element;
			const char* paths[] = { path.c_str() };
			options.paths.strings = (char**)paths;
			ASSERT(git_checkout_head(m_repo, &options));
		}
	}
	return success(true);
}

std::string GitManager::remove(const std::string& filelist)
{
	CHECK_REPO();
	GIT_index index;
	ASSERT(git_repository_index(&index, m_repo));
	nlohmann::json json = parse_file_list(filelist);
	if (json.is_array()) {
		for (auto element : json) {
			std::string path = element;
			ASSERT(git_index_remove_bypath(index, path.c_str()));
		}
	}
	ASSERT(git_index_write(index));
	return success(true);
}

std::string GitManager::info(const std::string& spec)
{
	CHECK_REPO();
	GIT_object head_commit;
	ASSERT(git_revparse_single(&head_commit, m_repo, spec.c_str()));
	return success(commit2json((git_commit*)(git_object*)head_commit));
}

std::string GitManager::history(const std::string& spec)
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
		json.push_back(commit2json(commit));
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
	nlohmann::json j;
	git_object_t type = git_tree_entry_type(entry);
	j["id"] = oid2str(git_tree_entry_id(entry));
	j["name"] = git_tree_entry_name(entry);
	j["type"] = type2str(type);
	j["root"] = root;
	((nlohmann::json*)payload)->push_back(j);
	return 0;
}

std::string GitManager::tree(const std::string& id)
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
	((nlohmann::json*)payload)->push_back(delta2json(delta));
	return 0;
}

std::string GitManager::diff(const std::u16string s1, const std::u16string& s2)
{
	CHECK_REPO();
	GIT_diff diff = NULL;
	if ((s1 == u"INDEX" && s2 == u"WORK") || (s2 == u"INDEX" && s1 == u"WORK")) {
		ASSERT(git_diff_index_to_workdir(&diff, m_repo, NULL, NULL));
	}
	else if ((s1 == u"HEAD" && s2 == u"INDEX") || (s2 == u"HEAD" && s1 == u"INDEX")) {
		GIT_object obj = NULL;
		ASSERT(git_revparse_single(&obj, m_repo, "HEAD^{tree}"));
		GIT_tree tree = NULL;
		ASSERT(git_tree_lookup(&tree, m_repo, git_object_id(obj)));
		ASSERT(git_diff_tree_to_index(&diff, m_repo, tree, NULL, NULL));
	}
	else if ((s1 == u"HEAD" && s2 == u"WORK") || (s2 == u"HEAD" && s1 == u"WORK")) {
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

std::string GitManager::file(const std::string& path, bool full)
{
	if (m_repo == nullptr) return {};
	git_oid oid;
	int ok = full
		? git_blob_create_fromdisk(&oid, m_repo, path.c_str())
		: git_blob_create_from_workdir(&oid, m_repo, path.c_str());
	if (ok < 0) return {};
	return oid2str(&oid);
}

namespace GIT {

	typedef enum {
		GIT_BOM_NONE = 0,
		GIT_BOM_UTF8 = 1,
		GIT_BOM_UTF16_LE = 2,
		GIT_BOM_UTF16_BE = 3,
		GIT_BOM_UTF32_LE = 4,
		GIT_BOM_UTF32_BE = 5
	} git_bom_t;

	static int git_buf_text_detect_bom(git_bom_t* bom, const git_buf* buf)
	{
		const char* ptr;
		size_t len;

		*bom = GIT_BOM_NONE;
		/* need at least 2 bytes to look for any BOM */
		if (buf->size < 2)
			return 0;

		ptr = buf->ptr;
		len = buf->size;

		switch (*ptr++) {
		case 0:
			if (len >= 4 && ptr[0] == 0 && ptr[1] == '\xFE' && ptr[2] == '\xFF') {
				*bom = GIT_BOM_UTF32_BE;
				return 4;
			}
			break;
		case '\xEF':
			if (len >= 3 && ptr[0] == '\xBB' && ptr[1] == '\xBF') {
				*bom = GIT_BOM_UTF8;
				return 3;
			}
			break;
		case '\xFE':
			if (*ptr == '\xFF') {
				*bom = GIT_BOM_UTF16_BE;
				return 2;
			}
			break;
		case '\xFF':
			if (*ptr != '\xFE')
				break;
			if (len >= 4 && ptr[1] == 0 && ptr[2] == 0) {
				*bom = GIT_BOM_UTF32_LE;
				return 4;
			}
			else {
				*bom = GIT_BOM_UTF16_LE;
				return 2;
			}
			break;
		default:
			break;
		}

		return 0;
	}
}

void GitManager::blob(VH id, VH encoding)
{
	if (m_repo == nullptr) { result = ::error(0); return; };

	git_oid oid;
	int ok = git_oid_fromstr(&oid, std::string(id).c_str());
	if (ok < 0) { result = ::error(); return; }

	GIT_blob blob = NULL;
	ok = git_blob_lookup(&blob, m_repo, &oid);
	if (ok < 0) { result = ::error(); return; }

	git_off_t rawsize = git_blob_rawsize(blob);
	const void* rawcontent = git_blob_rawcontent(blob);
	if (rawsize <= 0) return;

	const git_buf buf = GIT_BUF_INIT_CONST(rawcontent, rawsize);
	result.AllocMemory((unsigned long)rawsize);
	memcpy((void*)result.data(), rawcontent, rawsize);

	GIT::git_bom_t bom;
	bool binary = git_buf_is_binary(&buf);
	if (!binary) GIT::git_buf_text_detect_bom(&bom, &buf);
	encoding = binary ? -1 : bom;
}

bool GitManager::isBinary(VH blob, VH encoding)
{
	const git_buf buf = GIT_BUF_INIT_CONST(blob.data(), blob.size());
	GIT::git_bom_t bom;
	GIT::git_buf_text_detect_bom(&bom, &buf);
	bool binary = git_buf_is_binary(&buf);
	encoding = binary ? -1 : bom;
	return binary;
}

long GitManager::getEncoding(VH blob)
{
	const git_buf buf = GIT_BUF_INIT_CONST(blob.data(), blob.size());
	GIT::git_bom_t bom;
	GIT::git_buf_text_detect_bom(&bom, &buf);
	return bom;
}

#include <filesystem>

std::wstring GitManager::getFullpath(const std::wstring& path)
{
	if (m_repo == nullptr) return {};
	std::filesystem::path root = MB2WC(git_repository_path(m_repo));
	return root.parent_path().parent_path().append(path).make_preferred();
}
