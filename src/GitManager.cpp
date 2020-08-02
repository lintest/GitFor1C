#include "GitManager.h"
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

#define CHECK_REPO() {if (m_repo == nullptr) return error("Repo is null");}

#define ASSERT(t) {if (t < 0) return error();}

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
}                                      \
;

AUTO_GIT(GIT_signature, git_signature, git_signature_free)
AUTO_GIT(GIT_revwalk, git_revwalk, git_revwalk_free)
AUTO_GIT(GIT_commit, git_commit, git_commit_free)
AUTO_GIT(GIT_object, git_object, git_object_free)
AUTO_GIT(GIT_index, git_index, git_index_free)
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

static std::string getStatusText(git_status_t status) {
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

int status_cb(const char* path, unsigned int status_flags, void* payload)
{
	nlohmann::json* json = (nlohmann::json*)payload;
	nlohmann::json j, statuses;
	for (unsigned int i = 0; i < 16; i++) {
		git_status_t status = git_status_t(1u << i);
		if (status & status_flags) {
			statuses.push_back(getStatusText(status));
		}
	}
	j["filepath"] = path;
	j["statuses"] = statuses;
	json->push_back(j);
	return 0;
}

std::wstring GitManager::status()
{
	CHECK_REPO();
	nlohmann::json json, j;
	ASSERT(git_status_foreach(m_repo, status_cb, &j));
	json["result"] = j;
	return MB2WC(json.dump());
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
		NULL, S(msg),
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

std::string oid2str(const git_oid* id)
{
	const size_t size = GIT_OID_HEXSZ + 1;
	char buf[size];
	git_oid_tostr(buf, size, id);
	return buf;
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
